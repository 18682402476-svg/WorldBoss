// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BossCore.sol";
import "./FightRecords.sol";
import "./UserStats.sol";
import "./NftAwards.sol";

/**
 * @title WorldBossSystem
 * @dev 世界Boss战斗系统主合约，协调管理所有子合约
 * 
 * 系统架构：
 * ┌─────────────────────────────────────────────────────────┐
 * │                   WorldBossSystem                        │
 * │              （主入口， orchestrates 其他合约）           │
 * └─────────────────────────────────────────────────────────┘
 *           │                    │                    │
 *           ▼                    ▼                    ▼
 * ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
 * │    BossCore     │  │  FightRecords   │  │    UserStats    │
 * │ （Boss管理）    │  │ （战斗记录）     │  │ （用户统计）    │
 * └─────────────────┘  └─────────────────┘  └─────────────────┘
 *                              │
 *                              ▼
 *                   ┌─────────────────┐
 *                   │   NftAwards     │
 *                   │ （NFT奖励）      │
 *                   └─────────────────┘
 * 
 * 功能说明：
 * 1. 系统初始化：部署并连接所有子合约
 * 2. Boss管理：创建和管理Boss战斗
 * 3. 战斗处理：处理用户攻击，协调各合约更新
 * 4. 奖励分发：Boss被击败时发放NFT奖励
 * 5. 状态查询：提供统一的查询接口
 * 
 * 使用流程：
 * 1. 部署WorldBossSystem合约
 * 2. 调用initialize()初始化系统
 * 3. 调用createAndStartBossFight()创建Boss
 * 4. 用户调用attack()参与战斗
 * 5. Boss被击败后自动发放NFT奖励
 * 6. 10秒后Boss自动重生
 * 
 * 安全特性：
 * - 权限控制：只有所有者可以管理系统
 * - 重入保护：使用检查-效果-交互模式
 * - 随机数：使用区块链环境变量生成不可预测伤害
 */
contract WorldBossSystem {
    
    // 事件定义 - 用于前端监控和链下分析
    
    /** 
     * @dev 系统初始化完成事件
     */
    event SystemInitialized();
    
    /** 
     * @dev Boss战斗开始事件
     * @param bossId 新创建的Boss ID
     * @param bossName Boss名称
     */
    event BossFightStarted(uint256 bossId, string bossName);
    
    /** 
     * @dev Boss战斗结束事件
     * @param bossId Boss ID
     * @param topThree 前三名用户地址数组
     */
    event BossFightEnded(uint256 bossId, address[3] topThree);
    
    /** 
     * @dev 用户攻击事件
     * @param user 攻击者地址
     * @param bossId 被攻击的Boss ID
     * @param damage 造成的伤害值
     */
    event UserAttacked(address indexed user, uint256 bossId, uint256 damage);

    // 合约状态变量 - 子合约实例
    
    /**
     * @dev BossCore合约实例
     * @dev 负责Boss的创建、战斗和技能管理
     */
    BossCore public bossCore;
    
    /**
     * @dev FightRecords合约实例
     * @dev 负责记录战斗历史
     */
    FightRecords public fightRecords;
    
    /**
     * @dev UserStats合约实例
     * @dev 负责用户统计数据管理
     */
    UserStats public userStats;
    
    /**
     * @dev NftAwards合约实例
     * @dev 负责NFT奖励发放
     */
    NftAwards public nftAwards;

    // 系统状态变量
    
    /**
     * @dev 当前活跃的Boss ID
     * @dev 用于简化单Boss场景下的接口调用
     */
    uint256 public activeBossId;
    
    /**
     * @dev 合约所有者地址
     * @dev 拥有管理权限，可以初始化系统、创建Boss等
     */
    address public owner;

    // 访问控制修饰符
    
    /**
     * @dev 所有者检查修饰符
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // 构造函数
    
    /**
     * @dev 构造函数
     * @dev 设置合约部署者为所有者
     */
    constructor() {
        owner = msg.sender;
    }

    // 外部函数 - 系统初始化
    
    /**
     * @dev 初始化系统（通过外部部署的子合约）
     * @dev 使用已部署的子合约地址初始化系统，解决合约大小限制问题
     * @param _bossCore BossCore合约地址
     * @param _fightRecords FightRecords合约地址
     * @param _userStats UserStats合约地址
     * @param _nftAwards NftAwards合约地址
     */
    function initialize(
        address _bossCore,
        address _fightRecords,
        address _userStats,
        address _nftAwards
    ) external onlyOwner {
        // 使用已部署的合约地址
        bossCore = BossCore(_bossCore);
        fightRecords = FightRecords(_fightRecords);
        userStats = UserStats(_userStats);
        nftAwards = NftAwards(_nftAwards);

        emit SystemInitialized();
    }

    // 外部函数 - Boss管理
    
    /**
     * @dev 创建并启动Boss战斗
     * @dev 创建一个新Boss并设置为当前活跃Boss
     * @param name Boss名称
     * @param description Boss描述
     * @param maxHp Boss最大生命值
     * @param level Boss等级
     * @param imageUrl Boss图片URL 1
     * @param imageUrl2 Boss图片URL 2
     * @param goldNftUrl 第一名NFT图片URL
     * @param silverNftUrl 第二名NFT图片URL
     * @param bronzeNftUrl 第三名NFT图片URL
     * @return uint256 新创建的Boss ID
     */
    function createAndStartBossFight(
        string memory name,
        string memory description,
        uint256 maxHp,
        uint256 level,
        string memory imageUrl,
        string memory imageUrl2,
        string memory goldNftUrl,
        string memory silverNftUrl,
        string memory bronzeNftUrl,
        string memory skillName
    ) external onlyOwner returns (uint256) {
        // 创建Boss
        uint256 bossId = bossCore.createBoss(
            name, 
            description, 
            maxHp, 
            level, 
            imageUrl, 
            imageUrl2, 
            goldNftUrl, 
            silverNftUrl, 
            bronzeNftUrl,
            skillName
        );
        
        // 设置为当前活跃Boss
        activeBossId = bossId;
        
        emit BossFightStarted(bossId, name);
        return bossId;
    }



    // 外部函数 - 战斗逻辑
    
    /**
     * @dev 用户攻击当前活跃Boss
     * @dev 便捷方法，自动使用activeBossId
     * 
     * 处理流程：
     * 1. 检查Boss是否可被攻击
     * 2. 计算随机伤害
     * 3. 更新Boss血量
     * 4. 记录战斗记录
     * 5. 更新用户统计
     * 6. 检查并触发技能
     * 7. 检查Boss是否被击败
     */
    function attack() external {
        attackBoss(activeBossId);
    }

    /**
     * @dev 攻击指定Boss
     * @dev 完整的攻击处理逻辑
     * @param bossId 要攻击的Boss ID
     */
    function attackBoss(uint256 bossId) public {
        // 检查Boss是否可被攻击
        require(bossCore.checkCanAttack(bossId), "Boss cannot be attacked now");

        // 计算随机伤害
        uint256 damage = bossCore.calculateDamage();
        
        // 更新Boss血量，传递真正的用户地址
        uint256 bossHpAfter = bossCore.updateBossHp(bossId, msg.sender, damage);
        
        // 检查Boss是否被击败
        if (bossHpAfter == 0) {
            endBossFight(bossId);
        }
        
        emit UserAttacked(msg.sender, bossId, damage);
    }

    // 内部函数 - 战斗结束处理
    
    /**
     * @dev 结束Boss战斗
     * @dev 计算前三名用户并发放NFT奖励
     * @param bossId Boss ID
     */
    function endBossFight(uint256 bossId) internal {
        // 计算前三名用户
        address[3] memory topThree = userStats.calculateTopThree(bossId);
        
        // 获取Boss的NFT URL
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            string memory goldNftUrl,
            string memory silverNftUrl,
            string memory bronzeNftUrl,
            ,
            ,
            ,
            
        ) = bossCore.getBossInfo(bossId);
        
        // 发放NFT奖励，使用Boss特定的NFT图片URL
        if (topThree[0] != address(0)) {
            nftAwards.mintAwardWithUri(topThree[0], NftAwards.AwardType.Gold, goldNftUrl);
        }
        if (topThree[1] != address(0)) {
            nftAwards.mintAwardWithUri(topThree[1], NftAwards.AwardType.Silver, silverNftUrl);
        }
        if (topThree[2] != address(0)) {
            nftAwards.mintAwardWithUri(topThree[2], NftAwards.AwardType.Bronze, bronzeNftUrl);
        }
        
        emit BossFightEnded(bossId, topThree);
    }

    // 外部函数 - 查询接口
    
    /**
     * @dev 获取当前活跃Boss的状态
     * @return id Boss ID
     * @return name Boss名称
     * @return description Boss描述
     * @return maxHp 最大生命值
     * @return currentHp 当前生命值
     * @return level Boss等级
     * @return imageUrl Boss图片URL 1
     * @return imageUrl2 Boss图片URL 2
     * @return goldNftUrl 第一名NFT图片URL
     * @return silverNftUrl 第二名NFT图片URL
     * @return bronzeNftUrl 第三名NFT图片URL
     * @return attackCount 攻击次数
     * @return isActive 是否活跃
     * @return isDefeated 是否已击败
     * @return skillName 技能名称
     */
    function getActiveBossStatus() external view returns (
        uint256 id,
        string memory name,
        string memory description,
        uint256 maxHp,
        uint256 currentHp,
        uint256 level,
        string memory imageUrl,
        string memory imageUrl2,
        string memory goldNftUrl,
        string memory silverNftUrl,
        string memory bronzeNftUrl,
        uint256 attackCount,
        bool isActive,
        bool isDefeated,
        string memory skillName
    ) {
        return bossCore.getBossInfo(activeBossId);
    }

    /**
     * @dev 获取当前Boss的剩余血量百分比
     * @return uint256 血量百分比（0-100）
     */
    function getBossHpPercentage() external view returns (uint256) {
        return bossCore.getBossHpPercentage(activeBossId);
    }

    /**
     * @dev 获取当前Boss的最新攻击记录
     * @param count 要获取的记录数量（最大30）
     * @return FightRecords.AttackRecord[] 最新攻击记录数组
     */
    function getLatestAttackRecords(uint256 count) external view returns (FightRecords.AttackRecord[] memory) {
        return fightRecords.getLatestAttackRecords(activeBossId, count);
    }

    /**
     * @dev 获取用户在当前Boss战斗中的统计数据
     * @param user 用户地址
     * @return attackCount 攻击次数
     * @return totalDamage 总伤害值
     * @return lastAttackTime 最后攻击时间
     */
    function getUserStats(address user) external view returns (
        uint256 attackCount,
        uint256 totalDamage,
        uint256 lastAttackTime
    ) {
        return userStats.getUserStats(activeBossId, user);
    }

    /**
     * @dev 获取当前Boss的参与者数量
     * @return uint256 参与者数量
     */
    function getParticipantCount() external view returns (uint256) {
        return userStats.getParticipantCount(activeBossId);
    }

    // 外部函数 - 管理功能
    
    /**
     * @dev 设置NFT奖励的元数据URI
     * @param awardType 奖励类型（0=Gold, 1=Silver, 2=Bronze）
     * @param uri 元数据URI
     */
    function setAwardURI(uint256 awardType, string calldata uri) external onlyOwner {
        nftAwards.setAwardURI(NftAwards.AwardType(awardType), uri);
    }
}
