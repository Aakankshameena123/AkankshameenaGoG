const { ethers } = require("hardhat");

async function main() {
  const LiquidLoopFinance = await ethers.getContractFactory("LiquidLoopFinance");
  const liquidLoopFinance = await LiquidLoopFinance.deploy();

  await liquidLoopFinance.deployed();

  console.log("LiquidLoopFinance contract deployed to:", liquidLoopFinance.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
