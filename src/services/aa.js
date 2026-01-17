// Get boss top 3 damage dealers script
// Displays only user addresses and rankings for top 3

const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("=== Boss Damage Ranking - Top 3 ===\n");

  // Get boss ID from command line arguments
  const bossId = process.argv[2];
  if (!bossId) {
    console.error("❌ Usage: node scripts/get-boss-top-three.js <bossId>");
    console.error("Example: node scripts/get-boss-top-three.js 0");
    process.exit(1);
  }

  console.log(`📋 Querying top 3 for Boss ID: ${bossId}\n`);

  // Step 1: Load contract addresses
  let contractAddresses;
  try {
    const monadPath = path.join(__dirname, "../monad-contract-addresses.json");
    if (fs.existsSync(monadPath)) {
      contractAddresses = JSON.parse(fs.readFileSync(monadPath, "utf8"));
    } else {
      const localPath = path.join(__dirname, "../local-contract-addresses.json");
      if (fs.existsSync(localPath)) {
        contractAddresses = JSON.parse(fs.readFileSync(localPath, "utf8"));
      } else {
        console.error("❌ No contract addresses file found");
        process.exit(1);
      }
    }
  } catch (error) {
    console.error("❌ Error loading contract addresses:", error.message);
    process.exit(1);
  }

  // Step 2: Connect to the network
  let provider;
  try {
    if (contractAddresses.network === "Monad Testnet") {
      provider = new hre.ethers.providers.JsonRpcProvider("https://testnet-rpc.monad.xyz");
    } else {
      provider = new hre.ethers.providers.JsonRpcProvider("http://localhost:8545");
    }
  } catch (error) {
    console.error("❌ Error connecting to network:", error.message);
    process.exit(1);
  }

  // Step 3: Load UserStats contract
  let userStats;
  try {
    const userStatsAbi = require("../artifacts/contracts/UserStats.sol/UserStats.json").abi;
    userStats = new hre.ethers.Contract(
      contractAddresses.userStats,
      userStatsAbi,
      provider
    );
  } catch (error) {
    console.error("❌ Error loading UserStats contract:", error.message);
    process.exit(1);
  }

  // Step 4: Get all participants
  let participants;
  try {
    participants = await userStats.getAllParticipants(bossId);
    if (participants.length === 0) {
      console.log("ℹ️  No participants found for this boss.");
      process.exit(0);
    }
  } catch (error) {
    console.error("❌ Error getting participants:", error.message);
    process.exit(1);
  }

  // Step 5: Get damage stats for all participants
  let damageStats = [];
  try {
    for (const user of participants) {
      const stats = await userStats.getUserStats(bossId, user);
      damageStats.push({
        address: user,
        totalDamage: stats.totalDamage
      });
    }
  } catch (error) {
    console.error("❌ Error getting user stats:", error.message);
    process.exit(1);
  }

  // Step 6: Sort by total damage and get top 3
  damageStats.sort((a, b) => {
    return b.totalDamage.sub(a.totalDamage).toNumber();
  });

  const topThree = damageStats.slice(0, 3);

  // Step 7: Display top 3 with rankings
  console.log("🏆 Top 3 Damage Dealers:\n");
  
  topThree.forEach((participant, index) => {
    const rank = index + 1;
    const rankEmoji = rank === 1 ? "🥇" : rank === 2 ? "🥈" : "🥉";
    const rankText = rank === 1 ? "1st Place" : rank === 2 ? "2nd Place" : "3rd Place";
    
    console.log(`${rankEmoji} ${rankText}:`);
    console.log(`   Address: ${participant.address}`);
    console.log(`   Damage: ${participant.totalDamage.toString()}`);
    console.log("");
  });

  // Step 8: Summary
  console.log("📋 Summary:");
  console.log(`   Boss ID: ${bossId}`);
  console.log(`   Total Participants: ${damageStats.length}`);
  console.log(`   Top 3 Rankings Generated: ${topThree.length}`);

  console.log("\n=== Ranking Complete ===");
}

// Execute the script
main().catch((error) => {
  console.error("Error:", error);
  process.exitCode = 1;
});
