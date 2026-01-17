import { ethers } from 'ethers';

// 合约地址配置
const CONTRACT_ADDRESSES = {
  bossCore: '0x1FC341669CB5cd42cC7Cf72437D469b69444b98B',
  fightRecords: '0x9138ABEfb93114235A34A6023503730479F7758b',
  userStats: '0x82Bc97d68b938c3f092AD9DBa816a453937320e3',
  nftAwards: '0xE4FE18928b6c67Df8c106a8A31fc3b190533fE22',
  worldBossSystem: '0x19d542bD3854Db5606e3E87F896f811FE44d70C4'
};

// WorldBossSystem 合约 ABI
const WORLD_BOSS_SYSTEM_ABI = [
  "function attackBoss(uint256 bossId) external",
  "function getActiveBossStatus() external view returns (uint256 id, string memory name, string memory description, uint256 maxHp, uint256 currentHp, uint256 level, string memory imageUrl, string memory goldNftUrl, string memory silverNftUrl, string memory bronzeNftUrl, uint256 attackCount, bool isActive, bool isDefeated, string skill)",
  "function getBossHpPercentage() external view returns (uint256)",
  "function getUserStats(address user) external view returns (uint256 attackCount, uint256 totalDamage, uint256 rank)",
  "event UserAttacked(address indexed user, uint256 indexed bossId, uint256 damage)"
];

// BossCore 合约 ABI
const BOSS_CORE_ABI = [
  "function getBossInfo(uint256 bossId) external view returns (uint256 id, string memory name, string memory description, uint256 maxHp, uint256 currentHp, uint256 level, string memory imageUrl, string memory goldNftUrl, string memory silverNftUrl, string memory bronzeNftUrl, uint256 attackCount, bool isActive, bool isDefeated, string skillName)",
  "function getActiveBosses() external view returns (uint256[] memory)",
  "function getBossSkill(uint256 bossId, uint256 skillIndex) external view returns (string memory name, uint256 duration, uint256 triggerInterval, uint256 triggerAttackCount, bool isActive, uint256 activatedTime)",
  "event BossAttacked(address indexed attacker, uint256 indexed bossId, uint256 damage)",
  "event BossDefeated(uint256 indexed bossId, address[] topThree)",
  "event SkillTriggered(uint256 indexed bossId, string skillName)",
  "event SkillEnded(uint256 indexed bossId, string skillName)"
];

// FightRecords 合约 ABI
const FIGHT_RECORDS_ABI = [
  'function getLatestAttackRecords(uint256 bossId, uint256 count) external view returns (tuple(address attacker, uint256 timestamp, uint256 damage, uint256 bossHpAfter, uint8 recordType, string skillName)[])',
  "function getBossAttackRecords(uint256 bossId) external view returns (address[] memory attackers, uint256[] memory damages, uint256[] memory timestamps)"
];

// UserStats 合约 ABI
const USER_STATS_ABI = [
  "function getParticipantCount(uint256 bossId) external view returns (uint256)",
  "function getAllParticipants(uint256 bossId) external view returns (address[] memory)",
  "function getUserStats(uint256 bossId, address user) external view returns (uint256 attackCount, uint256 totalDamage, uint256 rank)"
];

/**
 * Ethereum 服务类
 * 提供以太坊区块链交互的常用方法
 */
class EthereumService {
  constructor() {
    this.provider = null;
    this.signer = null;
    this.contracts = {};
    this.eventListeners = [];
  }

  /**
   * 初始化以太坊服务
   * @returns {Promise<void>}
   */
  async init() {
    if (!window.ethereum) {
      throw new Error('Please install MetaMask or another Ethereum wallet first');
    }

    this.provider = new ethers.BrowserProvider(window.ethereum);
    this.signer = await this.provider.getSigner();
    this.contracts = await this.initContracts();
  }

  /**
   * 初始化所有合约实例
   * @returns {Promise<Object>}
   */
  async initContracts() {
    return {
      worldBossSystem: new ethers.Contract(
        CONTRACT_ADDRESSES.worldBossSystem,
        WORLD_BOSS_SYSTEM_ABI,
        this.signer
      ),
      bossCore: new ethers.Contract(
        CONTRACT_ADDRESSES.bossCore,
        BOSS_CORE_ABI,
        this.signer
      ),
      fightRecords: new ethers.Contract(
        CONTRACT_ADDRESSES.fightRecords,
        FIGHT_RECORDS_ABI,
        this.signer
      ),
      userStats: new ethers.Contract(
        CONTRACT_ADDRESSES.userStats,
        USER_STATS_ABI,
        this.signer
      )
    };
  }

  /**
   * 获取当前连接的账户地址
   * @returns {Promise<string>}
   */
  async getCurrentAccount() {
    if (!this.signer) {
      await this.init();
    }
    return await this.signer.getAddress();
  }

  /**
   * 攻击当前活跃Boss
   * @returns {Promise<ethers.ContractTransactionReceipt>}
   */
  async attack(id) {
    if (!this.contracts.worldBossSystem) {
      await this.init();
    }
    
    try {
      const tx = await this.contracts.worldBossSystem.attackBoss(id);
      const receipt = await tx.wait();
      return receipt;
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  /**
   * 获取当前活跃Boss信息
   * @returns {Promise<Object>}
   */
  async getActiveBossStatus() {
    if (!this.contracts.worldBossSystem) {
      await this.init();
    }
    
    try {
      const bossInfo = await this.contracts.worldBossSystem.getActiveBossStatus();
      return {
        id: bossInfo.id.toString(),
        name: bossInfo.name,
        description: bossInfo.description,
        maxHp: bossInfo.maxHp.toString(),
        currentHp: bossInfo.currentHp.toString(),
        level: bossInfo.level.toString(),
        imageUrl: bossInfo.imageUrl,
        goldNftUrl: bossInfo.goldNftUrl,
        silverNftUrl: bossInfo.silverNftUrl,
        bronzeNftUrl: bossInfo.bronzeNftUrl,
        attackCount: bossInfo.attackCount.toString(),
        isActive: bossInfo.isActive,
        isDefeated: bossInfo.isDefeated,
        skill: bossInfo.skill
      };
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  /**
   * 获取当前Boss HP百分比
   * @returns {Promise<number>}
   */
  async getBossHpPercentage() {
    if (!this.contracts.worldBossSystem) {
      await this.init();
    }

    try {
      const percentage = await this.contracts.worldBossSystem.getBossHpPercentage();
      return parseInt(percentage.toString());
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  /**
   * 获取用户战斗统计
   * @param {string} userAddress - 用户地址
   * @returns {Promise<Object>}
   */
  async getUserStats(userAddress) {
    if (!this.contracts.worldBossSystem) {
      await this.init();
    }
    
    try {
      const stats = await this.contracts.worldBossSystem.getUserStats(userAddress);
      console.log('stats',stats);
      
      return {
        attackCount: stats.attackCount.toString(),
        totalDamage: stats.totalDamage.toString(),
        rank: stats.rank.toString()
      };
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  /**
   * 获取最近攻击记录
   * @param {number} count - 记录数量
   * @returns {Promise<Object>}
   */
  async getLatestAttackRecords(id) {
    if (!this.contracts.fightRecords) {
      await this.init();
    }

    try {
      const records = await this.contracts.fightRecords.getLatestAttackRecords(id,10);
      
      return records.map((record) => ({
        attacker: record.attacker,
        timestamp: new Date(parseInt(record.timestamp.toString()) * 1000),
        damage: record.damage.toString(),
        bossHpAfter: record.bossHpAfter.toString(),
        recordType: record.recordType.toString(),
        skillName: record.skillName
      }));
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  /**
   * 获取Boss信息
   * @param {number} bossId - Boss ID
   * @returns {Promise<Object>}
   */
  async getBossInfo(bossId) {
    if (!this.contracts.bossCore) {
      await this.init();
    }

    try {
      const bossInfo = await this.contracts.bossCore.getBossInfo(bossId);
      console.log('bossInfo',bossInfo);
      
      return {
        id: bossInfo.id.toString(),
        name: bossInfo.name,
        description: bossInfo.description,
        maxHp: bossInfo.maxHp.toString(),
        currentHp: bossInfo.currentHp.toString(),
        level: bossInfo.level.toString(),
        difficulty: this.getRewardRarity(parseInt(bossInfo.level)),
        difficultyClass: this.getColorClass(bossInfo.name),
        colorClass: this.getColorClass(bossInfo.name),
        imageUrl: bossInfo.imageUrl,
        goldNftUrl: bossInfo.goldNftUrl,
        silverNftUrl: bossInfo.silverNftUrl,
        bronzeNftUrl: bossInfo.bronzeNftUrl,
        attackCount: bossInfo.attackCount.toString(),
        isActive: bossInfo.isActive,
        isDefeated: bossInfo.isDefeated,
        skillName: bossInfo.skill || ''
      };
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }
  // 获取颜色类名
  getColorClass = (name) => {
    if (name.includes('烈焰') || name.includes('火')) return 'fire';
    if (name.includes('冰霜') || name.includes('冰')) return 'ice';
    if (name.includes('暗影') || name.includes('暗')) return 'shadow';
    return 'fire';
  };

  // 获取奖励稀有度
  getRewardRarity = (level) => {
    if (level >= 3) return '史诗级';
    if (level >= 2) return '稀有级';
    return '普通级';
  };
  /**
   * 获取活跃Boss列表
   * @returns {Promise<Array<Object>>}
   */
  async getActiveBosses() {
    if (!this.contracts.bossCore) {
      await this.init();
    }

    try {
      const activeBossIds = await this.contracts.bossCore.getActiveBosses();
      const bosses = await Promise.all(
        activeBossIds.map(async id => await this.getBossInfo(id))
      );
      
      return bosses;
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }

  /**
   * 获取Boss技能信息
   * @param {number} bossId - Boss ID
   * @param {number} skillIndex - 技能索引
   * @returns {Promise<Object>}
   */
  async getBossSkill(bossId, skillIndex) {
    if (!this.contracts.bossCore) {
      await this.init();
    }

    try {
      const skill = await this.contracts.bossCore.getBossSkill(bossId, skillIndex);
      return {
        name: skill.name,
        duration: parseInt(skill.duration.toString()),
        triggerInterval: parseInt(skill.triggerInterval.toString()),
        triggerAttackCount: parseInt(skill.triggerAttackCount.toString()),
        isActive: skill.isActive,
        activatedTime: new Date(parseInt(skill.activatedTime.toString()) * 1000)
      };
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }


  /**
   * 错误处理
   * @param {Error} error - 错误对象
   */
  handleError(error) {
    if (error.message.includes('Boss not active')) {
      console.error('当前Boss不活跃');
    } else if (error.message.includes('Boss already defeated')) {
      console.error('Boss已被击败');
    } else if (error.message.includes('Boss cannot be attacked now')) {
      console.error('Boss暂时无法攻击');
    } else {
      console.error('交易失败:', error.message);
    }
  }

  /**
   * 格式化钱包地址（脱敏显示）
   * @param {string} address - 钱包地址
   * @returns {string}
   */
  formatWalletAddress(address) {
    if (!address) return '';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  }

  /**
   * 获取Boss伤害排行榜前3名
   * @param {number} bossId - Boss ID
   * @returns {Promise<Array<Object>>}
   */
  async getBossTopThree(bossId) {
    if (!this.contracts.userStats) {
      await this.init();
    }
    console.log(bossId);
    
    try {
      // 获取所有参与者
      const participants = await this.contracts.userStats.getAllParticipants(bossId);
      console.log('participants',participants);
      
      if (participants.length === 0) {
        return [];
      }

      // 获取每个参与者的伤害统计
      const damageStats = [];
      for (const user of participants) {
        const stats = await this.contracts.userStats.getUserStats(bossId, user);
        damageStats.push({
          address: user,
          totalDamage: stats.totalDamage
        });
      }

      // 按总伤害排序并获取前3名
      damageStats.sort((a, b) => {
        return b.totalDamage.sub(a.totalDamage).toNumber();
      });

      // 转换为字符串格式返回
      return damageStats.slice(0, 3).map(item => ({
        address: item.address,
        totalDamage: item.totalDamage.toString()
      }));
    } catch (error) {
      this.handleError(error);
      throw error;
    }
  }
}

// 导出单例实例
const ethereumService = new EthereumService();

export {
  ethereumService,
  EthereumService,
  CONTRACT_ADDRESSES
};
