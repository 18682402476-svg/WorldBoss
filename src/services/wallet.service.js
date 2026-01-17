import { ethers } from 'ethers';
import { setWalletAddress, setCurrentNetwork, disconnectWallet as resetWalletState } from '../store/gameState';

/**
 * 钱包服务类 - 处理钱包连接、断开、网络切换等功能
 * 基于ethers.js库与以太坊钱包（如MetaMask）进行交互
 */
class WalletService {
  constructor() {
    // 以太坊提供者实例
    this.provider = null;
    // 签名者实例，用于发起交易和签名
    this.signer = null;
    // 当前连接的钱包地址
    this.account = null;
    // 当前网络链ID
    this.chainId = null;
    // 钱包连接状态
    this.isConnected = false;
    // 事件监听器数组
    this.listeners = [];
  }

  /**
   * 初始化钱包服务
   * - 创建ethers提供者实例
   * - 设置事件监听器
   * - 检查现有连接
   */
  init() {
    // 检查浏览器是否支持以太坊钱包
    if (typeof window !== 'undefined' && window.ethereum) {
      // 创建ethers BrowserProvider实例
      this.provider = new ethers.BrowserProvider(window.ethereum);
      // 设置钱包事件监听器
      this.setupEventListeners();
      // 检查是否已有钱包连接
      this.checkExistingConnection();
    }
  }

  /**
   * 设置以太坊钱包事件监听器
   * - 监听账户变化
   * - 监听网络变化
   * - 监听连接状态变化
   * - 监听断开连接事件
   */
  setupEventListeners() {
    if (!window.ethereum) return;

    /**
     * 监听账户变化事件
     * 当用户切换钱包账户时触发
     */
    window.ethereum.on('accountsChanged', (accounts) => {
      if (accounts.length > 0) {
        // 更新账户信息
        this.account = accounts[0];
        this.isConnected = true;
        // 保存钱包地址到状态管理
        setWalletAddress(this.account);
        // 通知监听器账户已变更
        this.notifyListeners('accountChanged', this.account);
      } else {
        // 清空账户信息
        this.account = null;
        this.isConnected = false;
        // 清除状态管理中的钱包地址
        resetWalletState();
        // 通知监听器钱包已断开连接
        this.notifyListeners('disconnected');
      }
    });

    /**
     * 监听网络变化事件
     * 当用户切换网络时触发
     */
    window.ethereum.on('chainChanged', (chainId) => {
      // 更新链ID
      this.chainId = parseInt(chainId, 16);
      // 保存当前网络到状态管理
      setCurrentNetwork(this.chainId);
      // 通知监听器网络已变更
      this.notifyListeners('chainChanged', this.chainId);
    });

    /**
     * 监听钱包连接事件
     * 当钱包成功连接时触发
     */
    window.ethereum.on('connect', ({ chainId }) => {
      // 更新链ID
      this.chainId = parseInt(chainId, 16);
      // 更新连接状态
      this.isConnected = true;
      // 通知监听器钱包已连接
      this.notifyListeners('connected', { chainId: this.chainId });
    });

    /**
     * 监听钱包断开连接事件
     * 当钱包断开连接时触发
     */
    window.ethereum.on('disconnect', () => {
      // 清空账户信息
      this.account = null;
      this.isConnected = false;
      // 通知监听器钱包已断开连接
      this.notifyListeners('disconnected');
    });
  }

  /**
   * 检查现有钱包连接
   * - 调用eth_accounts方法获取当前账户
   * - 初始化钱包状态
   * - 保存钱包地址和网络到状态管理
   */
  async checkExistingConnection() {
    try {
      // 调用eth_accounts方法获取当前连接的账户
      const accounts = await this.provider.send('eth_accounts', []);
      console.log('检查现有连接:', accounts);
      
      if (accounts.length > 0) {
        // 更新账户信息
        this.account = accounts[0];
        this.isConnected = true;
        
        // 处理网络变化错误：检查连接过程中网络可能会切换
        try {
          const network = await this.provider.getNetwork();
          this.chainId = network.chainId;
        } catch (networkError) {
          // 忽略网络变化错误，使用默认的Monad Testnet链ID
          console.warn('检查连接过程中网络发生变化:', networkError.message);
          this.chainId = 10143; // Monad Testnet默认链ID
        }
        
        // 保存钱包地址和网络到状态管理
        setWalletAddress(this.account);
        setCurrentNetwork(this.chainId);
        
        // 通知监听器钱包已连接
        this.notifyListeners('connected', { account: this.account, chainId: this.chainId });
      }
    } catch (error) {
      console.error('检查现有连接失败:', error);
    }
  }

  /**
   * 连接钱包
   * - 调用eth_requestAccounts方法请求账户授权
   * - 初始化签名者
   * - 保存钱包地址和网络到状态管理
   * @returns {Promise<{success: boolean, account?: string, chainId?: number, error?: string}>} 连接结果
   */
  async connect() {
    try {
      if (!window.ethereum) {
        throw new Error('未检测到以太坊钱包，请安装MetaMask或其他钱包');
      }

      // 请求账户授权
      const accounts = await this.provider.send('eth_requestAccounts', []);
      if (accounts.length > 0) {
        // 更新账户信息
        this.account = accounts[0];
        this.isConnected = true;
        // 获取签名者实例
        this.signer = await this.provider.getSigner();
        
        // 处理网络变化错误：连接过程中网络可能会切换
        try {
          const network = await this.provider.getNetwork();
          this.chainId = Number(network.chainId);
        } catch (networkError) {
          // 忽略网络变化错误，使用默认的Monad Testnet链ID
          console.warn('连接过程中网络发生变化，将稍后更新:', networkError.message);
          this.chainId = 10143; // Monad Testnet默认链ID
        }
        
        // 保存钱包地址和网络到状态管理
        setWalletAddress(this.account);
        setCurrentNetwork(this.chainId);
        
        // 通知监听器钱包已连接
        this.notifyListeners('connected', { account: this.account, chainId: this.chainId });
        return { success: true, account: this.account, chainId: this.chainId };
      }
    } catch (error) {
      console.error('钱包连接失败:', error);
      // 通知监听器发生错误
      this.notifyListeners('error', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * 断开钱包连接
   * - 清空账户信息
   * - 清空签名者实例
   * - 更新连接状态
   * - 清除状态管理中的钱包地址和网络
   */
  async disconnect() {
    // 清空账户信息
    this.account = null;
    this.signer = null;
    this.isConnected = false;
    this.chainId = null;
    // 清除状态管理中的钱包地址和网络
    resetWalletState();
    // 通知监听器钱包已断开连接
    this.notifyListeners('disconnected');
  }

  /**
   * 重新连接钱包
   * - 尝试获取当前账户
   * - 如果获取失败，则调用connect方法重新连接
   * @returns {Promise<{success: boolean, account?: string, chainId?: number, error?: string}>} 重连结果
   */
  async reconnect() {
    try {
      if (!window.ethereum) {
        throw new Error('未检测到以太坊钱包');
      }

      // 尝试获取当前账户
      const accounts = await this.provider.send('eth_accounts', []);
      if (accounts.length > 0) {
        // 更新账户信息
        this.account = accounts[0];
        this.isConnected = true;
        // 获取签名者实例
        this.signer = await this.provider.getSigner();
        
        // 处理网络变化错误：重连过程中网络可能会切换
        try {
          const network = await this.provider.getNetwork();
          this.chainId = Number(network.chainId);
        } catch (networkError) {
          // 忽略网络变化错误，使用默认的Monad Testnet链ID
          console.warn('重连过程中网络发生变化，将稍后更新:', networkError.message);
          this.chainId = 10143; // Monad Testnet默认链ID
        }
        
        // 保存钱包地址和网络到状态管理
        setWalletAddress(this.account);
        setCurrentNetwork(this.chainId);
        
        // 通知监听器钱包已重连
        this.notifyListeners('reconnected', { account: this.account, chainId: this.chainId });
        return { success: true, account: this.account, chainId: this.chainId };
      } else {
        // 如果获取不到账户，则调用connect方法重新连接
        return await this.connect();
      }
    } catch (error) {
      console.error('钱包重连失败:', error);
      // 通知监听器发生错误
      this.notifyListeners('error', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * 获取当前连接的钱包地址
   * @returns {string|null} 当前钱包地址
   */
  getAccount() {
    return this.account;
  }

  /**
   * 获取当前网络链ID
   * @returns {number|null} 当前网络链ID
   */
  getChainId() {
    return this.chainId;
  }

  /**
   * 检查钱包连接状态
   * @returns {boolean} 钱包连接状态
   */
  isWalletConnected() {
    return this.isConnected;
  }

  /**
   * 添加事件监听器
   * @param {string} event 事件名称
   * @param {Function} callback 事件回调函数
   */
  on(event, callback) {
    this.listeners.push({ event, callback });
  }

  /**
   * 移除事件监听器
   * @param {string} event 事件名称
   * @param {Function} callback 事件回调函数
   */
  off(event, callback) {
    this.listeners = this.listeners.filter(
      listener => !(listener.event === event && listener.callback === callback)
    );
  }

  /**
   * 通知所有事件监听器
   * @param {string} event 事件名称
   * @param {any} data 事件数据
   */
  notifyListeners(event, data) {
    this.listeners.forEach(listener => {
      if (listener.event === event) {
        listener.callback(data);
      }
    });
  }

  /**
   * 获取Monad Testnet网络配置
   * @returns {Object} Monad Testnet网络配置（符合MetaMask标准）
   */
  getMonadTestnetConfig() {
    return {
      chainId: '0x279f', // 10143 in decimal - MetaMask中Monad Testnet的标准链ID
      chainName: 'Monad Testnet', // 必须与MetaMask中的网络名称完全一致
      nativeCurrency: {
        name: 'Monad', // 标准货币名称，符合MetaMask规范
        symbol: 'MON',
        decimals: 18
      },
      rpcUrls: ['https://testnet-rpc.monad.xyz', 'https://rpc.testnet.monad.xyz'], // 提供备选RPC URL
      blockExplorerUrls: ['https://testnet-explorer.monad.xyz']
    };
  }

  /**
   * 获取当前网络信息
   * @returns {Promise<{chainId: number}|null>} 当前网络信息
   */
  async getCurrentNetwork() {
    try {
      if (!this.provider) {
        throw new Error('钱包未连接');
      }
      // 获取当前网络信息
      const network = await this.provider.getNetwork();
      console.log('当前网络信息：',network);
      
      return { chainId: network.chainId };
    } catch (error) {
      console.error('获取当前网络信息失败:', error);
      return null;
    }
  }

  /**
   * 切换到Monad Testnet
   * - 检查当前网络是否已经是Monad Testnet
   * - 尝试直接切换网络
   * - 如果网络不存在，尝试添加网络
   * @returns {Promise<{success: boolean, message?: string, error?: string, code?: string}>} 切换结果
   */
  async switchToMonadTestnet() {
    try {
      if (!window.ethereum) {
        throw new Error('未检测到以太坊钱包，请安装MetaMask等钱包插件');
      }
  
      // Monad Testnet链ID（十进制）
      const MONAD_TESTNET_CHAIN_ID = 10143;
      
      // 检查当前网络是否已经是Monad Testnet
      const currentNetwork = await this.getCurrentNetwork();
      
      if (currentNetwork && Number(currentNetwork.chainId) === MONAD_TESTNET_CHAIN_ID) {
        console.log('当前已经是Monad Testnet网络，无需切换');
        return { success: true, message: '当前已经是Monad Testnet网络' };
      }
      
      // 尝试直接切换网络
      console.log('正在切换到Monad Testnet...');
      try {
        await this.switchChain();
        console.log('成功切换到Monad Testnet网络');
        return { success: true };
      } catch (switchError) {
        console.log('切换到Monad Testnet时发生错误:', switchError);
        
        // 优先判断用户拒绝
        if (switchError.code === 4001) {
          return { 
            success: false, 
            error: '你拒绝了网络切换请求',
            code: 'USER_REJECT'
          };
        }
        // 如果是网络不存在的错误，尝试添加网络
        if (switchError.code === 4902 || switchError.message.includes('Unrecognized chain ID')) {
          console.log('Monad Testnet网络不存在，正在添加网络...');
          const monadTestnetConfig = this.getMonadTestnetConfig();
          
          try {
            await this.addChain(monadTestnetConfig);
            return { success: true };
          } catch (addError) {
            console.error('添加Monad Testnet网络失败:', addError);
            return { 
              success: false, 
              error: '添加Monad Testnet网络失败，请手动添加',
              code: 'ADD_NETWORK_FAILED'
            };
          }
        } else {
          // 其他切换错误
          throw switchError;
        }
      }
    } catch (error) {
      console.error('切换到Monad Testnet时发生意外错误:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * 切换链
   * - 调用wallet_switchEthereumChain方法切换到指定链
   * @returns {Promise<{success: boolean}>} 切换结果
   */
  async switchChain() {
    try {
      // Monad Testnet链ID（十六进制）
      const hexChainId = '0x279f'
      
      // 调用wallet_switchEthereumChain方法切换链
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: hexChainId }]
      });
      
      console.log(`成功切换到链ID: ${hexChainId}`);
      return { success: true };
    } catch (error) {
     throw error;
    }
  }

  /**
   * 添加链
   * - 调用wallet_addEthereumChain方法添加新链
   * @param {Object} chainConfig 链配置信息
   * @returns {Promise<{success: boolean, error?: string}>} 添加结果
   */
  async addChain(chainConfig) {
    try {
      // 调用wallet_addEthereumChain方法添加链
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [chainConfig],
      });
      return { success: true };
    } catch (error) {
      console.error('添加网络失败:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * 清理资源
   * - 移除所有事件监听器
   * - 清空监听器数组
   */
  cleanup() {
    if (window.ethereum) {
      window.ethereum.removeAllListeners();
    }
    this.listeners = [];
  }
}

const walletService = new WalletService();

export default walletService;
