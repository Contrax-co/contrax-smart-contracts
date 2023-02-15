const {exec} = require('child_process');

async function main() {
  const platform = "fish";
  const names = [
    "wsteth-weth"
  ];

  const flatten = name => {
    console.log(`flatten ${name}`);
    console.log(`running: npx hardhat flatten ./contracts/vaults/${platform}/vault-${platform}-${name.toLowerCase()}.sol > ./flat/vaults/${platform}/vault-${platform}-${name.toLowerCase()}.sol`);
    exec(
      `npx hardhat flatten ./contracts/vaults/${platform}/vault-${platform}-${name.toLowerCase()}.sol > ./flat/vaults/${platform}/vault-${platform}-${name.toLowerCase()}.sol`, 
      (error, stdout, stderr) => {
        if (error) {
          console.error( `exec error: ${error}`);
          return;
        }
        console.log(`stdout: ${stdout}`);
        console.log(`stderr: ${stderr}`);
      }
    );
    console.log(`running: npx hardhat flatten ./contracts/strategies/${platform}/strategy-${platform}-${name.toLowerCase()}.sol > ./flat/strategies/${platform}/strategy-${platform}-${name.toLowerCase()}.sol`);
    exec(
      `npx hardhat flatten ./contracts/strategies/${platform}/strategy-${platform}-${name.toLowerCase()}.sol > ./flat/strategies/${platform}/strategy-${platform}-${name.toLowerCase()}.sol`, 
      (error, stdout, stderr) => {
        if (error) {
          console.error( `exec error: ${error}`);
          return;
        }
        console.log(`stdout: ${stdout}`);
        console.log(`stderr: ${stderr}`);
      }
    );
  };

  for (const name of names) {
    await flatten(name);
  }
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});