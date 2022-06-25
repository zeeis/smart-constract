# smart-contract
AptosFramework based Move smart contract for alphabiz-app credits

### Prerequisites

install aptos cli

### Init

```shell script
aptos init
```

### Move.toml :: Dependencies

use std lib: `AptosFramework`

```toml
AptosFramework = { local = "<local-aptos-core>/aptos-move/framework/aptos-framework" }
```

### Compile

```shell script
aptos move compile --package-dir <move-module-dir> --named-addresses ModAddr=<address>
```

Example

- move-module-dir: `.`
- address: `0xc089a56e7df48a8a93dd1115edaef073f17b278f7161432f4ffe35d846c490cb`

```shell script
aptos move compile --package-dir . --named-addresses ModAddr=0xc089a56e7df48a8a93dd1115edaef073f17b278f7161432f4ffe35d846c490cb
```

### Publish

```shell script
aptos move publish --package-dir <dir> --named-addresses ModAddr=<address>
```
