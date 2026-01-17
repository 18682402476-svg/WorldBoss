<template>
  <div class="app-container">
    <!-- 头部区域 -->
    <header class="header">
      <div class="logo" @click="goToHome">
        <div class="logo-icon">
          <img src="../plugins/newlogo.jpg" alt="" style="height: 50px;">
        </div>
        <div>
          <div class="logo-text">WORLD BOSS</div>
          <div class="monad-badge">Monad Boss Fighting</div>
        </div>
      </div>
      
      <div class="wallet-section">
        <div v-if="isConnected" class="connected-wallet">
          <div class="connected-badge">
            <span class="badge-dot"></span>
            <span class="badge-text">已连接</span>
          </div>
          <div class="wallet-address">
            {{ formatWalletAddress(walletAddress) }}
          </div>
          <button class="btn disconnect-btn" @click="disconnectWallet" :disabled="isLoading">
            <i v-if="isLoading" class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i>
            <i class="fas fa-sign-out-alt"></i>
          </button>
        </div>
        <div v-else class="connect-wallet">
          <button class="btn btn-primary" @click="connectWallet" :disabled="isLoading">
            <i v-if="isLoading" class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i>
            Connect Wallet
          </button>
        </div>
      </div>
    </header>

    <!-- 路由视图 -->
    <div class="main-content show">
      <router-view />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import walletService from './services/wallet.service';
import { useRouter } from 'vue-router';
const router = useRouter();
// 状态管理
const isConnected = ref(false);
const walletAddress = ref('');
const isLoading = ref(false);
const errorMessage = ref('');

// 初始化钱包服务
onMounted(() => {
  walletService.init();
  // 监听钱包连接事件
  walletService.on('connected', handleWalletConnected);
  walletService.on('disconnected', handleWalletDisconnected);
  walletService.on('error', handleWalletError);
  walletService.on('accountChanged', handleAccountChanged);
  
  // 检查现有连接
  isConnected.value = walletService.isWalletConnected();
  if (isConnected.value) {
    walletAddress.value = walletService.getAccount();
  }
});

// 清理事件监听
onUnmounted(() => {
  walletService.cleanup();
});

// 处理钱包连接成功
const handleWalletConnected = async (data) => {
  isConnected.value = true;
  walletAddress.value = data.account;
  isLoading.value = false;
  errorMessage.value = '';
  console.log('钱包连接成功:', data);
  
  // 钱包连接成功后，切换到Monad Testnet
  try {
    console.log('正在检查并切换到Monad Testnet...');
    const switchResult = await walletService.switchToMonadTestnet();
    if (switchResult.success) {
      if (switchResult.message) {
        console.log(switchResult.message);
      } else {
        console.log('成功切换到Monad Testnet');
      }
    } else {
      console.warn('切换到Monad Testnet失败:', switchResult.error);
      
      // 根据错误类型显示不同的提示信息
      if (switchResult.code === 'NETWORK_NOT_FOUND') {
        alert('Monad Testnet网络不存在，请先在钱包中添加该网络。\n\n添加步骤：\n1. 打开钱包\n2. 进入网络设置\n3. 添加网络\n4. 输入以下信息：\n   - 网络名称：Monad Testnet\n   - RPC URL：https://testnet-rpc.monad.xyz\n   - 链ID：10001\n   - 货币符号：MON\n   - 区块浏览器：https://testnet-explorer.monad.xyz');
      } else {
        // 不阻止用户使用，仅显示警告
        alert('建议切换到Monad Testnet以获得最佳体验。');
      }
    }
  } catch (error) {
    console.error('切换到Monad Testnet时发生错误:', error);
    // 显示错误提示，让用户了解情况
    alert('网络切换功能不可用，建议手动切换到Monad Testnet网络。');
  }
};

// 处理钱包断开连接
const handleWalletDisconnected = () => {
  isConnected.value = false;
  walletAddress.value = '';
  console.log('钱包已断开连接');
};

// 处理钱包错误
const handleWalletError = (error) => {
  isLoading.value = false;
  errorMessage.value = error.message;
  console.error('钱包错误:', error);
  alert('钱包操作失败: ' + error.message);
};

// 处理账户变化
const handleAccountChanged = (account) => {
  walletAddress.value = account;
  console.log('账户已变更:', account);
};

// 连接钱包
const connectWallet = async () => {
  isLoading.value = true;
  errorMessage.value = '';
  
  try {
    const result = await walletService.connect();
    if (!result.success) {
      alert('钱包连接失败: ' + result.error);
    }
  } catch (error) {
    alert('钱包连接失败: ' + error.message);
  } finally {
    isLoading.value = false;
  }
};

// 断开钱包连接
const disconnectWallet = () => {
  walletService.disconnect();
  goToHome()
};

const goToHome = () => {
  router.push('/');
};
// 格式化钱包地址显示
const formatWalletAddress = (address) => {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};
</script>

<style scoped>
/* 头部样式 */
.header {
    max-width: 1440px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px 0;
    border-bottom: 1px solid var(--border-color);
    margin-bottom: 30px;
}

.logo {
    display: flex;
    align-items: center;
    gap: 15px;
    cursor: pointer;
}

.logo-icon {
    width: 50px;
    height: 50px;
    background: var(--primary-gradient);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
}

.logo-text {
    font-family: 'Orbitron', sans-serif;
    font-weight: 900;
    font-size: 28px;
    background: var(--primary-gradient);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
}

.monad-badge {
    background: rgba(138, 43, 226, 0.1);
    border: 1px solid rgba(138, 43, 226, 0.3);
    border-radius: 20px;
    padding: 5px 15px;
    font-size: 14px;
    color: #8A2BE2;
    font-weight: 500;
}

/* 钱包连接区域 */
.wallet-section {
    display: flex;
    gap: 10px;
    align-items: center;
}

/* 已连接钱包样式 */
.connected-wallet {
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 24px;
    padding: 8px 12px;
    transition: all 0.3s ease;
}

.connected-wallet:hover {
    background: rgba(255, 255, 255, 0.1);
    transform: translateY(-2px);
}

/* 已连接徽章 */
.connected-badge {
    display: flex;
    align-items: center;
    gap: 6px;
    background: linear-gradient(135deg, #8A2BE2 0%, #9400D3 100%);
    color: white;
    padding: 4px 10px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 600;
}

.badge-dot {
    width: 6px;
    height: 6px;
    background: white;
    border-radius: 50%;
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0%, 100% {
        opacity: 1;
        transform: scale(1);
    }
    50% {
        opacity: 0.7;
        transform: scale(1.1);
    }
}

.badge-text {
    white-space: nowrap;
}

/* 钱包地址 */
.wallet-address {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-primary);
    font-family: monospace;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.3s ease;
}

.wallet-address:hover .copy-icon {
    opacity: 1;
    color: #8A2BE2;
}

.copy-icon {
    font-size: 12px;
    color: var(--text-secondary);
    opacity: 0.7;
    transition: all 0.3s ease;
}

/* 断开连接按钮 */
.disconnect-btn {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    padding: 6px;
    border-radius: 50%;
    cursor: pointer;
    transition: all 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 32px;
    min-height: 32px;
}

.disconnect-btn:hover {
    background: rgba(138, 43, 226, 0.1);
    color: #8A2BE2;
    transform: none;
    box-shadow: none;
}

/* 连接钱包按钮 */
.connect-wallet {
    display: flex;
    gap: 10px;
}

/* 响应式设计 - 头部 */
@media (max-width: 768px) {
    .header {
        flex-direction: column;
        gap: 20px;
        text-align: center;
    }
    
    .wallet-section {
        flex-direction: column;
        align-items: center;
        width: 100%;
    }
    
    .connected-wallet {
        width: 100%;
        justify-content: space-between;
    }
    
    .connect-wallet {
        width: 100%;
    }
    
    .connect-wallet .btn {
        width: 100%;
    }
}

/* 主内容区域 */
.main-content {
    opacity: 0;
    transition: opacity 0.5s ease;
}

.main-content.show {
    opacity: 1;
}

/* 响应式设计 - 头部 */
@media (max-width: 768px) {
    .header {
        flex-direction: column;
        gap: 20px;
        text-align: center;
    }
    
    .wallet-input {
        width: 100%;
    }
}
</style>