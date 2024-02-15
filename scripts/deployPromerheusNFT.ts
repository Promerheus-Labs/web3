import { ethers } from "hardhat";

async function main() {
  const PromerheusNFT = await ethers.getContractFactory("PromerheusNFT");

  const promerheus = await PromerheusNFT.deploy();
  await promerheus.waitForDeployment();

  console.log("ERC721 deployed to:", await promerheus.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
