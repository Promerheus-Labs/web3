import { ethers } from "hardhat";

async function main() {
  const PromerheusToken = await ethers.getContractFactory("PromerheusToken");

  const promerheus = await PromerheusToken.deploy();
  await promerheus.waitForDeployment();

  console.log("ERC20 deployed to:", await promerheus.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
