<template>
  <section class="boss-selection">
    <h2 class="section-title"><img style="width: 40px;height: 40px;" src="../../plugins/icon.svg" alt=""> 选择你的挑战目标</h2>
    <p style="color: var(--text-secondary); margin-bottom: 30px;">选择一个Boss开始挑战。每个Boss有不同的难度、血量和技能。</p>
    
    <div class="boss-cards">
      <div 
        v-for="boss in bosses" 
        :key="boss.id"
        class="boss-card" 
        :class="[boss.colorClass, { selected: selectedBoss === boss.id }]"
        @click="selectBoss(boss.id)"
      >
        <div class="boss-image">
          <img :src="boss.imageUrl" :alt="boss.name">
        </div>
        <div class="boss-header">
          <!-- <div :class="`${boss.colorClass}-icon`"> -->
            <img class="boss-icon" :src="boss.goldNftUrl" :alt="boss.name + ' icon'">
          <!-- </div> -->
          <div class="boss-info">
            <h3>{{ boss.name }}</h3>
            <span class="boss-difficulty" :class="boss.difficultyClass">{{ boss.difficulty }}</span>
          </div>
        </div>
        <p style="color: var(--text-secondary); margin-bottom: 15px; font-size: 14px;">{{ boss.description }}</p>
        <div class="boss-stats">
          <div class="stat">
            <div class="stat-value">{{ boss.currentHp }}</div>
            <div class="stat-label">生命值</div>
          </div>
          <div class="stat">
            <div class="stat-value">{{ boss.skillName }}</div>
            <div class="stat-label">特殊技能</div>
          </div>
          <div class="stat">
            <div class="stat-value">{{ boss.difficulty === '史诗级' ? '极高' : boss.difficulty === '稀有级' ? '中等' : '简单' }}</div>
            <div class="stat-label">难度</div>
          </div>
        </div>
      </div>
    </div>
    
    <div style="text-align: center; margin-top: 20px;">
      <button class="btn btn-primary" @click="startBattle" :disabled="!selectedBoss">
        <i class="fas fa-fist-raised"></i> Start Challenge
      </button>
    </div>
  </section>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ethereumService } from '@/services/ethereum.js';



const router = useRouter();

// 本地静态数据
const selectedBoss = ref(null);

// Boss数据
const bosses = ref([])

onMounted(async () => {
  // 从合约获取Boss数据
  bosses.value = await ethereumService.getActiveBosses();  
  console.log('bosses.value', bosses.value);
  
});

// Boss选择
const selectBoss = (bossId) => {
  selectedBoss.value = bossId;
};

// 开始战斗
const startBattle = () => {
  if (!selectedBoss.value) {
    return;
  }
  
  // 跳转到战斗页面
  router.push({path: '/battle', query: {bossId: selectedBoss.value}});
};
</script>

<style scoped>
/* Boss选择区域 */
.boss-selection {
    margin-bottom: 40px;
}

.boss-cards {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
    margin-bottom: 30px;
}

.boss-card {
  width: 380px;
  background: var(--card-bg);
  border-radius: 16px;
  padding: 20px;
  border: 2px solid transparent;
  transition: all 0.3s ease;
  cursor: pointer;
  position: relative;
  overflow: hidden;
}

.boss-card:hover {
    transform: translateY(-5px);
}

.boss-card.selected {
    border-color: #8A2BE2;
    box-shadow: 0 10px 30px rgba(138, 43, 226, 0.2);
}

.boss-card.fire {
    background: linear-gradient(145deg, rgba(255, 51, 0, 0.05), rgba(255, 153, 0, 0.05));
}

.boss-card.ice {
    background: linear-gradient(145deg, rgba(0, 102, 255, 0.05), rgba(0, 204, 255, 0.05));
}

.boss-card.shadow {
    background: linear-gradient(145deg, rgba(102, 0, 204, 0.05), rgba(153, 0, 255, 0.05));
}

.boss-header {
  display: flex;
  align-items: center;
  gap: 15px;
  margin-bottom: 15px;
}
.boss-image{
  width: 340px;
  height: 220px;
  background-color: rgba(242, 242, 242, 0.047058823529411764);
  border-radius: 20px;
  margin: 0 auto;
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.boss-image img{
  /* width: 80%; */
  height: 80%;
}
.boss-icon {
    width: 60px;
    height: 60px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 30px;
}

.fire-icon {
    background: var(--fire-gradient);
}

.ice-icon {
    background: var(--ice-gradient);
}

.shadow-icon {
    background: var(--shadow-gradient);
}

.boss-info h3 {
    font-family: 'Orbitron', sans-serif;
    font-size: 20px;
    margin-bottom: 5px;
}

.boss-difficulty {
    display: inline-block;
    padding: 3px 10px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 600;
}

.fire {
    background: rgba(255, 51, 0, 0.2);
    color: #FF3300;
}

.ice {
    background: rgba(0, 102, 255, 0.2);
    color: #0066FF;
}

.shadow {
    background: rgba(102, 0, 204, 0.2);
    color: #9900FF;
}

.boss-stats {
    display: flex;
    justify-content: space-between;
    margin-top: 15px;
    padding-top: 15px;
    border-top: 1px solid var(--border-color);
}

.stat {
    text-align: center;
}

.stat-value {
    font-family: 'Orbitron', sans-serif;
    font-size: 18px;
    font-weight: 700;
}

.stat-label {
    font-size: 12px;
    color: var(--text-secondary);
    margin-top: 3px;
}
/* 按钮样式 */
.btn {
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
    box-shadow: 0 10px 20px rgba(138, 43, 226, 0.3);
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
</style>
