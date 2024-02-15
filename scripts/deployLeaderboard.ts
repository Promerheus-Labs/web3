import { ethers } from "hardhat";

async function main() {
  const Leaderboard = await ethers.getContractFactory("Leaderboard");

  const leaderboard = await Leaderboard.deploy();

  await leaderboard.waitForDeployment();

  console.log("Leaderboard deployed to:", await leaderboard.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
