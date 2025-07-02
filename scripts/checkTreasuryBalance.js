// scripts/checkTreasuryBalance.js
const { ethers } = require("hardhat");

async function main() {
  const TREASURY = "0xYourTreasuryAddressHere";
  const balance = await ethers.provider.getBalance(TREASURY);
  console.log("Treasury ETH balance:", ethers.formatEther(balance), "ETH");
}
main().catch(console.error);
