<template>
  <section class="battle-section">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
      <h2 class="section-title">
        <img style="width: 40px;height: 40px;" src="../../plugins/icon.svg" alt="">
        战斗进行中{{ currentBoss ? '-' + currentBoss.name : '' }}
      </h2>
      <button style="width: 200px;" class="btn btn-secondary" @click="backToSelection">
        <i class="fas fa-arrow-left"></i> 返回选择
      </button>
    </div>
    
    <div class="battle-area" ref="battleArea">
      <!-- 技能警告效果 -->
      <div 
        class="skill-warning" 
        :class="{ 
          active: isSkillWarningActive, 
          [`${currentBoss.colorClass}-warning`]: currentBoss 
        }"
      ></div>
      
      <!-- 技能激活效果 -->
      <div 
        class="skill-active" 
        :class="{ 
          active: isSkillActive, 
          [`${currentBoss.colorClass}-active`]: currentBoss 
        }"
      ></div>
      
      <div class="boss-display">
        <div 
          class="boss-image" 
          :class="currentBoss ? currentBoss.colorClass : ''"
          ref="bossImage"
        >
           <img :src="currentBoss.imageUrl" alt="">
           <span v-if="damageNumber" class="damage-number">ASSAULT</span>
        </div>
        <div style="text-align: center;">
          <h3 style="font-family: 'Orbitron', sans-serif; font-size: 28px; margin-bottom: 10px;">{{ currentBoss ? currentBoss.name : '' }}</h3>
          <div class="boss-hp-bar">
            <div 
              class="boss-hp-fill" 
              :style="{ width: `${(currentBoss.currentHp / currentBoss.maxHp) * 100}%` }"
              :class="currentBoss ? `${currentBoss.colorClass}-hp` : ''"
            >
            </div>
            <span style="position: absolute;top: 0;left: 0;" class="hp-text">
              {{ currentBoss.currentHp.toLocaleString() }} / {{ currentBoss.maxHp.toLocaleString() }} 
            </span>
          </div>
        </div>
        <button 
          class="btn btn-primary attack-btn" 
          @click="attack" 
          :disabled="isSkillActive"
        >
          <i class="fas fa-bolt"></i> {{ isSkillActive ? '技能激活中 (2秒)' : '发动攻击' }}
        </button>
      </div>
      
      <!-- 战斗日志 -->
      <div class="battle-log">
        <div class="log-title"><i class="fas fa-scroll"></i> 战斗日志</div>
        <div id="battleLog">
          <div class="log-entry" v-for="(log, index) in battleLog" :key="index">
            <span class="log-time">{{ log.time }}</span>
            <span class="log-message">{{ log.message }}</span>
            <span v-if="log.type === 'damage'" class="log-damage">伤害</span>
            <span v-else-if="log.type === 'skill'" class="log-skill">提示</span>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 数据监控区域 -->
    <div class="stats-section">
      <div class="stat-card fire-border">
        <div class="stat-card-title">攻击统计</div>
        <div class="stat-card-value">{{ attackCount }}</div>
        <div class="stat-card-subtitle">总攻击次数</div>
      </div>
      
      <div class="stat-card ice-border">
        <div class="stat-card-title">造成伤害</div>
        <div class="stat-card-value">{{ totalDamage }}</div>
        <div class="stat-card-subtitle">总伤害值</div>
      </div>
      
      <div class="stat-card shadow-border">
        <div class="stat-card-title">Boss状态</div>
        <div class="stat-card-value">{{ bossHealthPercent }}%</div>
        <div class="stat-card-subtitle">剩余生命值</div>
      </div>
    </div>
    
    <!-- 交易确认模态框 -->
    <div class="modal" :class="{ active: isTransactionModalVisible }" id="transactionModal">
      <div class="modal-content">
        <div class="modal-header">
          <h3 class="modal-title"><i class="fas fa-file-contract"></i> 交易确认</h3>
          <button class="close-modal" @click="closeTransactionModal">&times;</button>
        </div>
        
        <div class="transaction-details">
          <div class="detail-row">
            <span class="detail-label">攻击目标:</span>
            <span class="detail-value">{{ currentBoss ? currentBoss.name : '' }}</span>
          </div>
    
          <div class="detail-row">
            <span class="detail-label">钱包地址:</span>
            <span class="detail-value">{{ formatWalletAddress(walletAddress) }}</span>
          </div>
          <div class="detail-row">
            <span class="detail-label">网络:</span>
            <span class="detail-value" style="color: #8A2BE2;">Monad测试网{{ currentNetwork }}</span>
          </div>
        </div>
        
        <div class="modal-footer">
          <button :disabled="loading" class="btn btn-secondary" @click="closeTransactionModal">取消</button>
          <button :disabled="loading" class="btn btn-primary" @click="confirmTransaction">确认攻击</button>
        </div>
      </div>
    </div>

    <!-- 排行榜模态框 -->
    <div class="modal" :class="{ active: isRewardModalVisible }" id="rewardModal">
      <div class="modal-content">
        <div class="modal-header">
          <h3 class="modal-title"><i class="fas fa-trophy"></i> Boss被击败！</h3>
          <button class="close-modal" @click="closeRewardModal">&times;</button>
        </div>
        
        <div class="leaderboard">
          <p style="color: var(--text-secondary); margin-bottom: 20px; text-align: center;">
            恭喜以下玩家成功击败Boss！
          </p>
          
          <div class="leaderboard-list">
            <div 
              v-for="(player, index) in topThreePlayers" 
              :key="index"
              class="leaderboard-item"
              :class="`rank-${index + 1}`"
            >
              <div class="rank-badge">
                <img style="height: 40px;" :src="player.rank === 1 ? currentBoss.goldNftUrl : player.rank === 2 ? currentBoss.silverNftUrl : currentBoss.bronzeNftUrl" alt="">
              </div>
              <div class="player-info">
                <div class="player-address">{{ formatWalletAddress(player.address) }}</div>
                <div class="player-stats">
                  <!-- <span>攻击次数: {{ player.attackCount }}</span> -->
                  <span>总伤害: {{ player.totalDamage }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <div class="modal-footer">
          <button class="btn btn-primary" @click="closeRewardModal">确定</button>
        </div>
      </div>
    </div>
    
  </section>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { walletAddress, currentNetwork } from '../store/gameState';
import { ethereumService } from '@/services/ethereum.js';

const router = useRouter();
const route = useRoute();

// 本地状态管理
const currentBoss = ref({
  id: "",
  name: "",
  description: "",
  maxHp: "",
  currentHp: "",
  level: "",
  imageUrl: "",
  goldNftUrl: "",
  silverNftUrl: "",
  bronzeNftUrl: "",
  attackCount: "",
  isActive: false,
  isDefeated: false,
  skillCount: "",
  skills: [],
  colorClass: "",
  skillName: "",
  rewardName: "",
  rewardRarity: ""
});

const isBattling = ref(false);
const attackCount = ref(0);
const totalDamage = ref(0);
const bossMaxHealth = ref(0);
const bossCurrentHealth = ref(0);
const bossHealthPercent = ref(0);
const isSkillActive = ref(false);
const isSkillWarningActive = ref(false);
const battleLog = ref([]);
const isTransactionModalVisible = ref(false);
const isRewardModalVisible = ref(false);
const damageNumber = ref(false);
const loading = ref(false);
const topThreePlayers = ref([]);
// 技能计时器
let bossSkillInterval = null;

// 更新Boss生命值百分比
const updateBossHealthPercent = () => {
    bossHealthPercent.value = ((currentBoss.value.currentHp / currentBoss.value.maxHp) * 100).toFixed(2);
};

// 添加战斗日志
const addLogEntry = (message, type = "info") => {
    const now = new Date();
    const timeString = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`;
    
    battleLog.value.unshift({
        time: timeString,
        message: message,
        type: type
    });
    
    // 限制日志数量
    if (battleLog.value.length > 10) {
        battleLog.value.pop();
    }
};

// 格式化钱包地址（脱敏显示）
const formatWalletAddress = (address) => {
    if (!address) return '';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

// 初始化
onMounted(async() => {
  // 从路由参数获取bossId
  const bossId = route.query.bossId;
  
  // 从合约获取Boss数据
  currentBoss.value = await ethereumService.getBossInfo(bossId)

  // 初始化战斗状态
  isBattling.value = true;
  attackCount.value = 0;
  totalDamage.value = 0;
  bossMaxHealth.value = currentBoss.maxHealth;
  bossCurrentHealth.value = currentBoss.currentHealth;
  // 更新Boss生命值百分比
  updateBossHealthPercent();
  // 刷新用户统计
  refreshUserStats();
  // 刷新战斗日志
  refreshBattleLog();
  // 开始Boss技能循环
  startBossSkillCycle();
});

// 清理计时器
onUnmounted(() => {
  stopBossSkillCycle();
});

// 返回Boss选择
const backToSelection = () => {
  // 停止技能循环
  stopBossSkillCycle();
  
  // 跳转回Boss选择页面
  router.push('/boss-selection');
};

// 攻击
const attack = async () => {
  if (isSkillActive.value) {
    addLogEntry("Boss技能激活中，无法攻击！", "skill");
    return;
  }
  isTransactionModalVisible.value = true;

  
};
// 关闭交易模态框
const closeTransactionModal = () => {
  isTransactionModalVisible.value = false;
  addLogEntry("取消了攻击");
};

// 执行攻击
const confirmTransaction = async() => {
  if (isSkillActive.value) {
    addLogEntry("Boss技能激活中，无法攻击！", "skill");
    return;
  }
  try {
    loading.value = true
    // 显示加载状态
    addLogEntry("正在发起攻击交易...", "info");
    
    // 调用合约攻击方法
    await ethereumService.attack( currentBoss.value.id );
    isTransactionModalVisible.value = false;
    loading.value = false
    // 交易成功
    addLogEntry("攻击交易已确认", "info");
    // 刷新Boss数据
    await refreshBossData();
    
    // 刷新用户统计
    await refreshUserStats();
    
    // 刷新战斗日志
    await refreshBattleLog();
    
  } catch (error) {
    console.error('攻击失败:', error);
    addLogEntry(`攻击失败: ${error.message}`, "info");
  }
};

// 刷新Boss数据
const refreshBossData = async () => {
  try {
    const bossId = route.query.bossId;
    const bossData = await ethereumService.getBossInfo(bossId);
    
    // 更新Boss数据
    currentBoss.value = {
      ...currentBoss.value,
      currentHp: bossData.currentHp,
      maxHp: bossData.maxHp,
      attackCount: bossData.attackCount,
    };
    
    // 更新本地状态
    bossCurrentHealth.value = parseInt(bossData.currentHp);
    bossMaxHealth.value = parseInt(bossData.maxHp);
    attackCount.value = parseInt(bossData.attackCount);
    
    // 更新UI
    updateBossHealthPercent();
    
    // 检查Boss是否被击败
    if (bossData.currentHp <= 0) {
      showReward();
    }
  } catch (error) {
    console.error('刷新Boss数据失败:', error);
  }
};

// 刷新用户统计
const refreshUserStats = async () => {
  try {
    const userAddress = await ethereumService.getCurrentAccount();
    const stats = await ethereumService.getUserStats(userAddress);
    
    // 更新统计数据
    totalDamage.value = parseInt(stats.totalDamage);
    attackCount.value = parseInt(stats.attackCount);
  } catch (error) {
    console.error('刷新用户统计失败:', error);
  }
};

// 刷新战斗日志
const refreshBattleLog = async () => {
  try {
    const bossId = route.query.bossId;
    const records = await ethereumService.getLatestAttackRecords(bossId);
    records.reverse();
    // 清空现有日志
    battleLog.value = [];
    
    // 添加合约返回的日志
    records.forEach(item => {
      const now = new Date(item.timestamp);
      const timeString = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`;
      
      battleLog.value.push({
        time: timeString,
        message: `玩家 ${formatWalletAddress(item.attacker)} 对Boss造成了 ${item.damage} 点伤害`,
        type: 'damage'
      });
    });
  } catch (error) {
    console.error('刷新战斗日志失败:', error);
  }
};

// 获取前三名玩家
const getTopThreePlayers = async () => {
  try {
    // 使用新创建的方法获取前三名玩家
    const topThree = await ethereumService.getBossTopThree(route.query.bossId);
    
    // 转换为需要的格式
    topThreePlayers.value = topThree.map(player => ({
      address: player.address,
      totalDamage: parseInt(player.totalDamage),
      attackCount: 0 // 新方法暂时不返回攻击次数
    }));
  } catch (error) {
    console.error('获取前三名玩家失败:', error);
  }
};

// Boss技能循环
const startBossSkillCycle = () => {
  // 清除现有的计时器
  stopBossSkillCycle();
  
  // 每10秒触发一次技能
  bossSkillInterval = setInterval(() => {
    if (!currentBoss.value) return;
    
    // 技能预警（1秒）
    isSkillWarningActive.value = true;
    addLogEntry(`${currentBoss.value.name}正在准备释放${currentBoss.value.skillName}！`, "skill");
    
    setTimeout(() => {
      // 技能激活（2秒）
      isSkillWarningActive.value = false;
      isSkillActive.value = true;
      
      addLogEntry(`${currentBoss.value.skillName}！无法攻击！`, "skill");
      
      setTimeout(() => {
        // 技能结束
        isSkillActive.value = false;
        
        addLogEntry(`${currentBoss.value.skillName}结束，可以继续攻击`, "skill");
      }, 2000);
    }, 100);
  }, 10000);
};

// 停止Boss技能循环
const stopBossSkillCycle = () => {
  if (bossSkillInterval) {
    clearInterval(bossSkillInterval);
    bossSkillInterval = null;
    isSkillActive.value = false;
    isSkillWarningActive.value = false;
  }
};

// 显示奖励
const showReward = async () => {
  if (!currentBoss.value) return;
  
  // 获取前三名玩家
  await getTopThreePlayers();
  
  // 显示奖励模态框
  isRewardModalVisible.value = true;
  
  // 停止技能循环
  stopBossSkillCycle();
  
};

// 关闭奖励模态框
const closeRewardModal = () => {
  isRewardModalVisible.value = false;
};

</script>

<style scoped>
/* 战斗区域 */
.battle-section {
    display: block;
}

.battle-area {
    background: var(--card-bg);
    border-radius: 16px;
    padding: 30px;
    margin-bottom: 30px;
    position: relative;
    overflow: hidden;
    min-height: 500px;
}

.boss-display {
    width: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 20px;
    margin-bottom: 30px;
}

.boss-image {
    width: 600px;
    height: 400px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 80px;
    background-color: rgba(242, 242, 242, 0.047058823529411764);
    transition: all 0.3s ease;
    padding: 20px;
    border-radius: 20px;
    position: relative;
}
.boss-image img{
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.damage-number{
  font-size: 80px;
  color: #9933FF;
  position: absolute;
  bottom: 80px;
  right: 200px;
}

.boss-hp-bar {
  width: 200px;
  height: 40px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 20px;
  position: relative;
}

.boss-hp-fill {
  height: 100%;
  padding: 0 20px;
  border-radius: 40px;
  transition: width 0.5s ease;
  position: relative;
}

.fire-hp {
  background: var(--fire-gradient);
}

.ice-hp {
  background: var(--ice-gradient);
}

.shadow-hp {
  background: var(--shadow-gradient);
}

.hp-text {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: 'Orbitron', sans-serif;
    font-weight: 700;
    font-size: 14px;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
}

.battle-controls {
    display: flex;
    flex-direction: column;
    gap: 20px;
    margin-bottom: 30px;
}

.attack-btn {
    padding: 20px;
    font-size: 18px;
    font-weight: 700;
    font-family: 'Orbitron', sans-serif;
}

.concurrent-demo {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 20px;
    margin-top: 20px;
}

.demo-progress {
    width: 100%;
    height: 10px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 5px;
    margin: 15px 0;
    overflow: hidden;
}

.demo-progress-fill {
    height: 100%;
    background: var(--primary-gradient);
    border-radius: 5px;
    width: 0%;
    transition: width 0.3s ease;
}

/* 数据监控区域 */
.stats-section {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
    margin-bottom: 40px;
}

.stat-card {
    background: var(--card-bg);
    border-radius: 12px;
    padding: 20px;
    border-left: 4px solid;
}

.stat-card.fire-border {
    border-left-color: #9933FF;
}

.stat-card.ice-border {
    border-left-color: #6666FF;
}

.stat-card.shadow-border {
    border-left-color: #9900FF;
}

.stat-card.normal-border {
    border-left-color: #8A2BE2;
}

.stat-card-title {
    font-size: 14px;
    color: var(--text-secondary);
    margin-bottom: 10px;
}

.stat-card-value {
    font-family: 'Orbitron', sans-serif;
    font-size: 28px;
    font-weight: 700;
}

.stat-card-subtitle {
    font-size: 12px;
    color: var(--text-secondary);
    margin-top: 5px;
}

/* 交易确认模态框 */
.modal {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.8);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    opacity: 0;
    visibility: hidden;
    transition: all 0.3s ease;
}

.modal.active {
    opacity: 1;
    visibility: visible;
}

.modal-content {
    background: var(--bg-darker);
    border-radius: 16px;
    padding: 30px;
    max-width: 500px;
    width: 90%;
    border: 1px solid var(--border-color);
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
}

.modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
}

.modal-title {
    font-family: 'Orbitron', sans-serif;
    font-size: 20px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.close-modal {
    background: none;
    border: none;
    color: var(--text-secondary);
    font-size: 24px;
    cursor: pointer;
    transition: color 0.3s ease;
}

.close-modal:hover {
    color: var(--text-primary);
}

.transaction-details {
    background: rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    padding: 20px;
    margin: 20px 0;
}

.detail-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 10px;
    padding-bottom: 10px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.detail-row:last-child {
    margin-bottom: 0;
    padding-bottom: 0;
    border-bottom: none;
}

.detail-label {
    color: var(--text-secondary);
}

.detail-value {
    font-weight: 600;
    font-family: 'Orbitron', sans-serif;
}

.modal-footer {
    display: flex;
    justify-content: center;
    gap: 15px;
    margin-top: 30px;
}

/* 排行榜模态框 */
.leaderboard {
    text-align: center;
}

.leaderboard-list {
    display: flex;
    flex-direction: column;
    gap: 15px;
    margin-top: 20px;
}

.leaderboard-item {
    display: flex;
    align-items: center;
    gap: 15px;
    padding: 15px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.05);
    border: 2px solid transparent;
}

.leaderboard-item.rank-1 {
    border-color: #FFD700;
    background: rgba(255, 215, 0, 0.1);
}

.leaderboard-item.rank-2 {
    border-color: #C0C0C0;
    background: rgba(192, 192, 192, 0.1);
}

.leaderboard-item.rank-3 {
    border-color: #CD7F32;
    background: rgba(205, 127, 50, 0.1);
}

.rank-badge {
    width: 50px;
    height: 50px;
    font-size: 32px;
    min-width: 50px;
    text-align: center;
}

.player-info {
    flex: 1;
    text-align: left;
}

.player-address {
    font-family: 'Orbitron', sans-serif;
    font-size: 16px;
    font-weight: 600;
    margin-bottom: 5px;
}

.player-stats {
    display: flex;
    gap: 20px;
    font-size: 14px;
    color: var(--text-secondary);
}

/* 技能特效 */
.skill-warning {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    border-radius: 16px;
    pointer-events: none;
    z-index: 1;
    opacity: 0;
}

.skill-warning.active {
    animation: warningPulse 1s infinite;
}

@keyframes warningPulse {
    0%, 100% { opacity: 0.1; }
    50% { opacity: 0.3; }
}

.skill-active {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    border-radius: 16px;
    pointer-events: none;
    z-index: 2;
    opacity: 0;
}

.skill-active.active {
    animation: skillActive 2s;
}

@keyframes skillActive {
    0% { opacity: 0; }
    20% { opacity: 0.7; }
    80% { opacity: 0.7; }
    100% { opacity: 0; }
}

.fire-warning {
    background: rgba(255, 51, 0, 0.2);
    box-shadow: 0 0 100px rgba(255, 51, 0, 0.5) inset;
}

.ice-warning {
    background: rgba(0, 102, 255, 0.2);
    box-shadow: 0 0 100px rgba(0, 102, 255, 0.5) inset;
}

.shadow-warning {
    background: rgba(102, 0, 204, 0.2);
    box-shadow: 0 0 100px rgba(102, 0, 204, 0.5) inset;
}

.fire-active {
    background: rgba(255, 51, 0, 0.4);
    box-shadow: 0 0 150px rgba(255, 51, 0, 0.8) inset;
}

.ice-active {
    background: rgba(0, 102, 255, 0.4);
    box-shadow: 0 0 150px rgba(0, 102, 255, 0.8) inset;
}

.shadow-active {
    background: rgba(102, 0, 204, 0.4);
    box-shadow: 0 0 150px rgba(102, 0, 204, 0.8) inset;
}

/* 伤害数字效果 */
.damage-number {
    position: absolute;
    font-family: 'Orbitron', sans-serif;
    font-weight: 900;
    font-size: 24px;
    text-shadow: 0 0 10px rgba(255, 0, 0, 0.8);
    pointer-events: none;
    z-index: 10;
    animation: floatUp 1.5s ease-out forwards;
}

@keyframes floatUp {
    0% {
        opacity: 1;
        transform: translateY(0) scale(1);
    }
    100% {
        opacity: 0;
        transform: translateX(100px) scale(1);
    }
}
/* 按钮样式 */
.btn {
    width: 60%;
    padding: 12px 24px;
    border-radius: 8px;
    border: none;
    font-weight: 600;
    font-size: 16px;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
}

.btn-primary {
    background: var(--primary-gradient);
    color: white;
}

.btn-primary:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 20px rgba(255, 138, 0, 0.3);
}

.btn-secondary {
    background: rgba(255, 255, 255, 0.1);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
}

.btn-secondary:hover {
    background: rgba(255, 255, 255, 0.15);
}

.btn-danger {
    background: var(--danger-color);
    color: white;
}

.btn:disabled {
    background: var(--disabled-color);
    cursor: not-allowed;
    transform: none !important;
    box-shadow: none !important;
}
/* 战斗日志 */
.battle-log {
    background: rgba(0, 0, 0, 0.3);
    border-radius: 12px;
    padding: 20px;
    margin-top: 20px;
    max-height: 200px;
    overflow-y: auto;
}

.log-title {
    font-size: 16px;
    margin-bottom: 10px;
    color: var(--text-secondary);
    display: flex;
    align-items: center;
    gap: 8px;
}

.log-entry {
    padding: 8px 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    font-size: 14px;
    display: flex;
    align-items: center;
    gap: 10px;
}

.log-time {
    color: var(--text-secondary);
    font-family: monospace;
}

.log-message {
    flex-grow: 1;
}

.log-damage {
    color: #9933FF;
    font-weight: 700;
    font-family: 'Orbitron', sans-serif;
}

.log-skill {
    color: #8A2BE2;
}
</style>
