import { ref, reactive } from 'vue';

/**
 * 游戏状态管理模块
 * - 管理钱包状态
 * - 管理战斗状态
 * - 使用sessionStorage实现状态持久化
 */

// 钱包状态 - 响应式变量
// 当前连接的钱包地址
const walletAddress = ref('');
// 钱包连接状态
const isWalletConnected = ref(false);
// 当前网络
const currentNetwork = ref('');


/**
 * 设置钱包地址
 * @param {string} address 钱包地址
 */
export const setWalletAddress = (address) => {
  walletAddress.value = address;
  isWalletConnected.value = !!address;
  // 保存到sessionStorage，刷新后保持连接状态
  if (address) {
    sessionStorage.setItem('walletAddress', address);
  } else {
    sessionStorage.removeItem('walletAddress');
  }
};

/**
 * 获取钱包地址
 * @returns {string} 当前钱包地址
 */
export const getWalletAddress = () => {
  return walletAddress.value;
};

/**
 * 检查钱包连接状态
 * @returns {boolean} 钱包连接状态
 */
export const checkWalletConnection = () => {
  return isWalletConnected.value;
};

/**
 * 设置当前网络
 * @param {string|number} network 网络名称或链ID
 */
export const setCurrentNetwork = (network) => {
  currentNetwork.value = network;
  // 保存到sessionStorage
  sessionStorage.setItem('currentNetwork', network);
};

/**
 * 获取当前网络
 * @returns {string|number} 当前网络
 */
export const getCurrentNetwork = () => {
  return currentNetwork.value;
};

/**
 * 初始化钱包状态
 * - 从sessionStorage加载钱包地址
 * - 从sessionStorage加载网络信息
 */
export const initWalletState = () => {
  // 从sessionStorage加载钱包地址
  const savedAddress = sessionStorage.getItem('walletAddress');
  if (savedAddress) {
    walletAddress.value = savedAddress;
    isWalletConnected.value = true;
  }
  
  // 从sessionStorage加载网络信息
  const savedNetwork = sessionStorage.getItem('currentNetwork');
  if (savedNetwork) {
    currentNetwork.value = savedNetwork;
  }
};

/**
 * 断开钱包连接
 * - 清空钱包地址
 * - 重置连接状态
 * - 清空当前网络
 * - 清除sessionStorage中的数据
 */
export const disconnectWallet = () => {
  walletAddress.value = '';
  isWalletConnected.value = false;
  currentNetwork.value = '';
  sessionStorage.removeItem('walletAddress');
  sessionStorage.removeItem('currentNetwork');
};



// 导出状态变量
export { 
  walletAddress,      // 当前钱包地址
  isWalletConnected,  // 钱包连接状态
  currentNetwork     // 当前网络
 };
