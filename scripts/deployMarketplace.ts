import { ethers } from "hardhat";

async function main() {
  const MarketPlace = await ethers.getContractFactory("MarketPlace");

  const marketplace = await MarketPlace.deploy(
    "0xAA214E8613c22f7116Eb9357C8A1CC3FaddAFA57",
    "0x13AE9640A066F51abfe9fF0805B28B8254ff4D8f"
  );
  await marketplace.waitForDeployment();

  console.log("Marketplace deployed to:", await marketplace.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
