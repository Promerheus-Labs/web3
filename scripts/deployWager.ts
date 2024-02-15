import { ethers } from "hardhat";

async function main() {
  const Wager = await ethers.getContractFactory("Wager");

  const wager = await Wager.deploy();
  await wager.waitForDeployment();

  console.log("Wager deployed to:", await wager.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
