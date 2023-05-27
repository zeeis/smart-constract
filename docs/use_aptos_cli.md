
## Usage

> learn latest tutorials: \
> https://aptos.dev/tools/aptos-cli-tool/use-aptos-cli

### Init

```shell script
aptos init
```

##### Dev Network

- fullnode url: `https://fullnode.devnet.aptoslabs.com`
- faucet url: `https://faucet.devnet.aptoslabs.com`

##### Local Network

- fullnode url: `http://localhost:8080`
- faucet url: `http://localhost:8000`

### Move.toml :: Dependencies

use std lib: `AptosFramework`

```toml
AptosFramework = { local = "<local-aptos-core>/aptos-move/framework/aptos-framework" }
```

### Test

```shell script
aptos move test --package-dir <move-module-dir> --named-addresses ModAddr=<address>
```

### Compile

```shell script
aptos move compile --package-dir <move-module-dir> --named-addresses ModAddr=<address>
```

### Publish

```shell script
aptos move publish --package-dir <dir> --named-addresses ModAddr=<address>
```

## Example

- move-module-dir: `.`
- address: `a8dc8272faff7c58bc7b2c31fc540988420709a50878c8a68001e1c265de0f56`

> restore my account:\
> copy `<private_key>` from `/.aptos/config.yaml`\
> then call `$blockchain.Dev.restoreAccount(<private_key>)` to restore your account

```shell script

aptos move test --package-dir . --named-addresses ModAddr=a8dc8272faff7c58bc7b2c31fc540988420709a50878c8a68001e1c265de0f56

```

```shell script

aptos move compile --package-dir . --named-addresses ModAddr=a8dc8272faff7c58bc7b2c31fc540988420709a50878c8a68001e1c265de0f56

```

```shell script

aptos move publish --package-dir . --named-addresses ModAddr=a8dc8272faff7c58bc7b2c31fc540988420709a50878c8a68001e1c265de0f56

```
