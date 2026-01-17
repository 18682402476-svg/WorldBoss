<template>
<div class="login-container">
  <div class="login-section">
    <div style="margin-bottom: 20px;">
      <img style="width: 80px;height: 80px;" src="../../plugins/icon.svg" alt="">
    </div>
    <h1>欢迎来到World Boss挑战平台</h1>
    <p class="login-section__description">
      这是一个专门展示Monad区块链并行执行能力的游戏化演示。通过挑战强大的Boss，体验Monad链的高TPS、低延迟和低成本特性。
    </p>
    
      <div class="login-features">
        <div class="feature-item">
          <img src="../../plugins/icon1.svg" alt="">
          <h3>并行执行</h3>
          <p>支持大规模并发攻击</p>
        </div>
        <div class="feature-item">
          <img src="../../plugins/icon2.svg" alt="">
          <h3>游戏化体验</h3>
          <p>沉浸式Boss战斗</p>
        </div>
        <div class="feature-item">
          <img src="../../plugins/icon3.svg" alt="">
          <h3>NFT奖励</h3>
          <p>击败Boss获得专属NFT</p>
        </div>
      </div>
    
    
    <button class="btn btn-primary" @click="startDemo" :disabled="!isConnected">
      <i class="fas fa-play"></i> Fighting
    </button>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import walletService from '../services/wallet.service';

const router = useRouter();

// 钱包连接状态
const isConnected = ref(false);

// 初始化钱包服务
onMounted(() => {
  walletService.init();
  
  // 检查当前连接状态
  isConnected.value = walletService.isWalletConnected();
  
  // 监听钱包连接事件
  walletService.on('connected', () => {
    isConnected.value = true;
  });
  
  walletService.on('disconnected', () => {
    isConnected.value = false;
  });
});

// 清理事件监听
onUnmounted(() => {
  walletService.off('connected', () => {
    isConnected.value = true;
  });
  
  walletService.off('disconnected', () => {
    isConnected.value = false;
  });
});

const startDemo = () => {
  router.push('/boss-selection');
};
</script>

<style scoped>
.login-container {
  width: 100%;
  position: relative;
  overflow: hidden;
  border-radius: 30px;
  margin-top: 20px;
}
.login-container::before{
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: url('../../plugins/newback.jpg') no-repeat;
  background-size: cover;
  filter: brightness(40%); /* 调整背景亮度 */
  z-index: -1;
}
/* 登录界面 */
.login-section {
  text-align: center;
  padding: 10px 20px 170px 20px;
  max-width: 800px;
  margin: 0 auto;
}
.login-section__description{
  font-weight: 900;
}

.login-section h1 {
  font-family: 'Orbitron', sans-serif;
  font-size: 36px;
  margin-bottom: 20px;
  background: var(--primary-gradient);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
}
.login-section h3 {
  font-family: 'Orbitron', sans-serif;
  font-size: 16px;
  margin: 20px;
}

.login-section p {
  color: var(--text-secondary);
  font-size: 18px;
  margin-bottom: 40px;
  line-height: 1.6;
}

.login-features {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 20px;
  margin-bottom: 40px;
}

.feature-item {
    text-align: center;
    width: 150px;
}

.feature-item i {
  font-size: 24px;
  color: #8A2BE2;
  margin-bottom: 10px;
}
.feature-item .fa-gamepad{
  color: #9400D3;
}
.feature-item .fa-gem{
  color: #9370DB;
}
.feature-item h3 {
    font-weight: 600;
    margin-bottom: 5px;
}

.feature-item p {
    font-size: 14px;
    margin-bottom: 0;
}
/* 按钮样式 */
.btn {
  margin: 0 auto;
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
</style>
