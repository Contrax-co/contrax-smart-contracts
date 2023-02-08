<div align="center">
<h1>Contrax Finance</h1>

<p>This repository includes Solidity files for Contrax's underlying smart contracts.</p>
</div>

---

## Getting Started

We are using Hardhat to compile and test our smart contracts. 
To create a reproducible environment, please use Hardhat locally when setting up your project. This will avoid version conflicts. 

To install all the necessary dependencies, run: 

```shell
npm i 
```

To run any local hardhat scripts, use `npx hardhat`. 

--- 

## Testing

By default, tests are executed on a fork of Arbitrum One. 

To create local accounts for testing, create a copy of the .env file containing your addresses/keys: 

```shell 
cp .env.example .env
```

If you run into any memory related errors, use the following to allocate more heap space to your node process:

```
export NODE_OPTIONS=--max_old_space_size=4096
```

To compile and run all testing scripts available in the `/test/` directory, use the following:

```shell
npx hardhat test
```

> To learn more about the tests available and how to run them, click [here](test/README.md).

To find the slot of a token, install and run the slot20 tool (https://github.com/kendricktan/slot20):

```
npm i slot20
```
In another terminal, run:

```
slot20 balanceOf <token address> <token holder> --rpc https://arb1.arbitrum.io/rpc
```

--- 
## Deployments

In order to deploy a contract, you will first need to flatten its files. To do this run the following code:

```shell 
npx hardhat flatten
```

The flattened file can be used to deploy the contract through Remix. 

---

## Naming Conventions

### Strategy names:
Strategy names should include reference to the platform and the token(s) affected. 

For example StrategySushiWethDai.
Let's break this down:

Strategy - this is the type of contract that it is
Sushi - this is the platform it is built upon
Weth - this is the primary token bound in the liquidity pool
Dai - this is the secondary token bound in the liquidity pool

It's worth noting that the strategies, as well as all other contracts, are written in UpperCamelCase format. This is in keeping with standard Object Oriented fashion since the contracts are Classes and follow standard Inheretance.

### Function names
Functions within the contracts should be written in lowerCamelCase. This is again in keeping with standard software engineering practices, both within and outside of Object Oriented Programing. 

Functions that are private, that is, functions that can only be called by the parent class, should be prepended by an underscore '_' like so _lowerCamelcase.

### Variable names
Variables, should only contain lowercase letters, words separated by an underscore '_' (this is often called snake_case), unless the variable is representing an instantiated object of a class (contract or interface), in which case, it can follow the UpperCamelCase form used by objects.

### Parameter names
In order to match the convention elsewhere in our codebase, parameters should follow standard variable naming convention, except in the case that the parameter represents a class variable (field) that is being overwritten by the function (such as in a constructor). In this case, the parameter name should also be prepended by an underscore '_' like so _snake_case. 


## Contracts

### Main Contrax Contracts
Name | Address
--- | ---
Governance | 0xCb410A689A03E06de0a6247b13C13D14237DecC8
Timelock | 0xCb410A689A03E06de0a6247b13C13D14237DecC8

> A more comprehensive list of all Vaults contracts along with their respective strategies and controllers can be found in our documentation [here](https://docs.contrax.finance/introduction).

---

## Contributors

<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
      <td align="center"><a href="https://github.com/AbigailTCameron"><img src="https://avatars.githubusercontent.com/u/75511255?v=4" width="100px;" alt=""/><br /><sub><b>Abigail</b></sub></a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->