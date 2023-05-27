import { exists } from 'https://deno.land/std/fs/mod.ts'
import { resolve } from 'https://deno.land/std/path/mod.ts'
import inquirer from 'npm:inquirer@9.1.4'

const mainWorker = createWorker(MainWorker, {
  logger: (...args) => {
    console.log('[cleaner]', ...args)
  },
  imported: [
    'import { exists } from "https://deno.land/std/fs/mod.ts";',
    'import { resolve } from "https://deno.land/std/path/mod.ts";',
  ]
})

await startController()
async function startController(){
  let current_status = { state: 'Running', pending: false }

  console.log('[controller]','Starting...')
  await mainWorker.post('start', 24 * 60 * 60_000)
  // await mainWorker.post('start', 24 * 60 * 60_000)
  console.log('[controller]','Started')
  while (current_status.state !== 'Stopped') {
    const handlers = getCurrentHandlers()
    const title = `Controller: (${current_status.state})`
    const choice = Object.values(handlers)[await promptChoice(title, Object.values(handlers).map(x => x.message))]
    // if (current_status.state === choice.value) continue
    current_status.state = choice.value
    await choice.handler?.()
  }
  await mainWorker.close()
  console.log('[controller]', 'Closed')


  function getCurrentHandlers () {
    const res = {
      Paused: {
        message: 'pause',
        handler: () => mainWorker.post('pause'),
      },
      Running: {
        message: 'resume',
        handler: () => mainWorker.post('resume'),
      },
      Stopped: {
        message: 'stop',
        handler: () => mainWorker.post('stop'),
      },
    }
    Object.entries(res).forEach(([k,v])=>v.value=k)
    return res
  }
  async function promptChoice (message, choices, def) {
    const { choice } = await inquirer.prompt([
      {
        type: 'list',
        name: 'choice',
        message: message,
        choices: choices,
        default: def ?? 0
      },
    ])
    return choices.indexOf(choice)
  }
}

// -----------------------------------------------------------

function MainWorker () {
  async function main () {
    const dirname = '/var/lib/docker/volumes/aws-validator_aptos-shared'
    const limit = 256_000_000
    self.logger('Cleaning...', new Date().toISOString())
    self.logger('- limit:', limit)
    self.logger('- dirname:', dirname)
    await startupCleaner(dirname, limit)
    self.logger('Cleaned', new Date().toISOString())
  }

  let state = 'stop'
  let loopHandler = () => {
  }

  const start = async (interval) => {
    await new Promise(resolve => {
      loopHandler = resolve
      state = 'start'
      loop(main, interval)
    })
  }
  const stop = async () => {
    await new Promise(resolve => {
      loopHandler = resolve
      state = 'stop'
    })
  }
  const pause = async () => {
    await new Promise(resolve => {
      loopHandler = resolve
      state = 'paused'
    })
  }
  const resume = async () => {
    await new Promise(resolve => {
      loopHandler = resolve
      state = 'resume'
    })
  }
  return {
    start: start,
    stop: stop,
    pause: pause,
    resume: resume,
  }

  async function loop (main, interval) {
    let resumed = null
    while (state !== 'stop') {
      // self.logger('state:', state, resumed)
      if (state === 'paused') {
        sync()
        await wait(1000)
      } else {
        await main()
        sync()
        resumed = state
        state = 'paused'
        wait(interval).then(() => {
          if (!resumed) return
          state = resumed
          resumed = null
        })
      }
    }
    sync()

    function sync () {
      if (!loopHandler) return
      resumed = null
      loopHandler()
      loopHandler = null
    }

    function wait (x) {
      return new Promise(resolve => setTimeout(resolve, x))
    }
  }

  async function startupCleaner (dirname, limit) {
    if (!await exists(dirname)) return

    let size_total = 0
    const files = []
    files.push({filename: resolve(dirname, '_data/validator.log')})
    const dir_list = [
      '_data/0/db/consensusdb',
      '_data/0/db/ledger_db',
      '_data/0/db/state_merkle_db',
    ]
    for (const dir of dir_list) {
      for await (const entry of Deno.readDir(resolve(dirname, dir))) {
        if (!entry.isFile) continue
        if (
          (entry.name === 'LOG') ||
          entry.name.startsWith('LOG.old.')
        ) {
          files.push({filename: resolve(dirname, dir, entry.name)})
        }
      }
    }
    for (const file of files) {
      const { size } = await Deno.stat(file.filename)
      size_total += parseInt(size)
      file.size = size
      self.logger(`${file.size}\t| ${file.filename}`)
    }
    self.logger('Total Size:', `${Math.round(size_total/limit * 100 * 100)/100}%`, `(${size_total} / ${limit})`)

    if (size_total >= limit) { // 256m
      await Promise.all(files.map(async file => {
        if (file.size === 0) {
          // await Deno.remove(file.filename)
        } else {
          await Deno.truncate(file.filename)
        }
      }))
    }
  }
}

// -----------------------------------------------------------

function createWorker (fn, { imported, logger }) {

  const imports = () => ({
    onInit: () => imported.join('\n')
  })

  const utils = () => ({
    onInit: () => () => {
      self.$emit = ($name, data) => self.postMessage({ $name: $name, ...data })
      self.$on = ($name, cb) => {
        self.addEventListener('message', ({ data }) => {
          if (data.$name !== $name) return
          cb(data, {
            $emit: (data) => self.$emit($name, data)
          })
        })
      }
    },
    onCreated (worker) {
      worker.$on = ($name, cb) => {
        worker.addEventListener('message', ({ data }) => {
          if (data.$name !== $name) return
          cb(data)
        })
      }
      worker.$emit = ($name, data) => {
        worker.postMessage({
          ...data,
          $name: $name
        })
      }
    }
  })

  const log = (logger) => ({
    onInit: () => () => {
      self.logger = (...args) => {
        self.$emit('log', { args })
      }
    },
    onCreated (worker) {
      worker.$on('log', ({ args }) => logger(...args))
    }
  })

  const jobs = (createHandlers) => {
    const pendingJobs = {}
    return {
      onInit () {
        return `(${(workerHandler).toString()})((${createHandlers.toString()})())`

        function workerHandler (handlers) {
          const handleMessage = async (type, params) => {
            if (!handlers[type]) return
            return await handlers[type](...params)
          }
          self.$on('jobs', async (data, { $emit }) => {
            const res = await handleMessage(data.type, data.params)
            $emit({
              id: data.id,
              result: res
            })
          })
        }
      },
      onCreated (worker) {
        worker.$on('jobs', ({
                              id,
                              result
                            }) => {
          pendingJobs[id](result)
          delete pendingJobs[id]
        })
      },
      onExport (worker, target) {
        Object.assign(target, {
          post: (type, ...params) => new Promise(resolve => {
            const id = String(Math.random())
            pendingJobs[id] = resolve
            worker.$emit('jobs', {
              id,
              type,
              params
            })
          })
        })
      }
    }
  }

  const modules = [imports(), utils(), log(logger), jobs(fn)]
  const worker = new Worker(URL.createObjectURL(new Blob([modules.map(mod => mod.onInit()).map(x => typeof x === 'string' ? x : `(${x.toString()})()`).join(';\n')])), { type: 'module' })
  const target = {}
  modules.forEach(mod => mod.onCreated?.(worker))
  modules.forEach(mod => mod.onExport?.(worker, target))
  Object.assign(target, {
    close: () => worker.terminate(),
  })
  return target
}
