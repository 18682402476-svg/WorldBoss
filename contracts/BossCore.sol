// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title BossCore
 * @dev Boss核心合约，管理Boss的创建、战斗、技能和重生
 * 
 * 功能说明：
 * 1. 创建和管理Boss实例，包括Boss属性（名称、血量、等级）
 * 2. 处理用户对Boss的攻击，计算伤害并更新Boss状态
 * 3. 管理Boss技能系统，支持定时触发和按攻击次数触发
 * 4. 实现Boss被击败后的自动重生机制（10秒后）
 * 5. 提供Boss状态查询接口
 * 6. 支持活跃Boss列表过滤功能
 * 
 * 伤害计算：
 * - 随机伤害范围：100-500
 * - 使用区块链不可预测因素（时间戳、区块难度等）生成随机数
 * 
 * 重生机制：
 * - Boss被击败后自动进入重生状态
 * - 10秒后自动恢复满血重生
 * - 重生后重置攻击计数和技能状态
 * 
 * 与其他合约的交互：
 * - FightRecords: 记录每次攻击的详细信息
 * - UserStats: 更新用户的攻击统计数据
 * - NftAwards: Boss被击败时触发NFT奖励发放
 */
contract BossCore {
    
    // 事件定义 - 用于前端监控、链下分析和事件索引
    
    /** 
     * @dev Boss创建事件
     * @param bossId 新创建的Boss ID
     * @param name Boss名称
     * @param maxHp Boss最大生命值
     * @param description Boss描述
     * @param imageUrl Boss图片URL
     */
    event BossCreated(uint256 bossId, string name, uint256 maxHp, string description, string imageUrl);
    
    /** 
     * @dev Boss被攻击事件
     * @param attacker 攻击者地址
     * @param bossId 被攻击的Boss ID
     * @param damage 本次攻击造成的伤害
     * @param bossHpAfter 攻击后Boss剩余血量
     */
    event BossAttacked(address indexed attacker, uint256 bossId, uint256 damage, uint256 bossHpAfter);
    //。。。。。。。。。。。。。。。。。。。
    /** 
     * @dev 技能触发事件
     * @param bossId Boss ID
     * @param skillName 技能名称
     * @param duration 技能持续时间（秒）
     */
    event SkillTriggered(uint256 bossId, string skillName, uint256 duration);
    
    /** 
     * @dev 技能结束事件
     * @param bossId Boss ID
     * @param skillName 技能名称
     */
    event SkillEnded(uint256 bossId, string skillName);
    
    /** 
     * @dev Boss被击败事件
     * @param bossId Boss ID
     * @param topThree 前三名用户地址数组
     */
    event BossDefeated(uint256 bossId, address[] topThree);

    // 数据结构定义
    
    /**
     * @dev 记录类型枚举
     * @dev 用于区分不同类型的战斗记录
     */
    enum RecordType {
        Attack,      // 普通攻击
        Skill,       // 技能攻击
        SkillEnd     // 技能结束
    }

    /**
     * @dev Boss数据结构
     * @dev 存储Boss的所有属性和状态信息
     */
    struct Boss {
        uint256 id;                       // Boss唯一标识符
        string name;                      // Boss名称
        string description;               // Boss描述
        uint256 maxHp;                    // 最大生命值
        uint256 currentHp;                // 当前生命值
        uint256 level;                    // Boss等级
        string imageUrl;                  // Boss图片URL 1
        string imageUrl2;                 // Boss图片URL 2
        string goldNftUrl;                // 第一名NFT图片URL
        string silverNftUrl;              // 第二名NFT图片URL
        string bronzeNftUrl;              // 第三名NFT图片URL
        uint256 attackCount;              // 累计攻击次数
        bool isActive;                    // 是否处于活跃状态
        bool isDefeated;                  // 是否已被击败
        string skillName;                 // 技能名称
        uint256 respawnTime;              // 下次重生时间（Unix时间戳）
        bool isRespawning;                // 是否正在重生中
    }

    // 存储映射
    
    /**
     * @dev Boss映射
     * @dev 按Boss ID索引，存储所有Boss的信息
     */
    mapping(uint256 => Boss) public bosses;
    
    /**
     * @dev 下一个Boss ID
     * @dev 递增计数器，用于为新Boss分配唯一ID
     */
    uint256 public nextBossId;

    // 合约状态变量 - 关联合约地址
    
    /** 
     * @dev WorldBossSystem主合约地址
     */
    address public worldBossSystemContract;
    
    /** 
     * @dev FightRecords战斗记录合约地址
     */
    address public fightRecordsContract;
    
    /** 
     * @dev UserStats用户统计合约地址
     */
    address public userStatsContract;
    
    /** 
     * @dev NftAwards NFT奖励合约地址
     */
    address public nftAwardsContract;

    // 内部状态变量
    
    /**
     * @dev 随机数生成种子
     * @dev 用于生成不可预测的随机伤害值
     */
    uint256 private randomSeed;

    // 权限控制
    
    /**
     * @dev 合约所有者地址
     */
    address public owner;

    /**
     * @dev 所有者检查修饰符
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @dev 系统合约检查修饰符
     * @dev 验证调用者是否为授权的系统合约之一
     */
    modifier onlySystem() {
        require(
            msg.sender == fightRecordsContract ||
            msg.sender == userStatsContract ||
            msg.sender == nftAwardsContract,
            "Not authorized system contract"
        );
        _;
    }

    // 构造函数
    
    /**
     * @dev 构造函数
     * @dev 初始化合约所有者和随机数种子
     */
    constructor() {
        owner = msg.sender;
        randomSeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
    }

    // 外部函数 - 合约设置和管理
    
    /**
     * @dev 设置关联合约地址
     * @dev 在部署后调用，建立合约间的依赖关系
     * @param _fightRecordsContract FightRecords合约地址
     * @param _userStatsContract UserStats合约地址
     * @param _nftAwardsContract NftAwards合约地址
     */
    function setContractAddresses(
        address _fightRecordsContract,
        address _userStatsContract,
        address _nftAwardsContract
    ) external onlyOwner {
        fightRecordsContract = _fightRecordsContract;
        userStatsContract = _userStatsContract;
        nftAwardsContract = _nftAwardsContract;
    }
    
    /**
     * @dev 设置WorldBossSystem合约地址
     * @param _worldBossSystemContract WorldBossSystem合约地址
     */
    function setWorldBossSystemContract(address _worldBossSystemContract) external onlyOwner {
        worldBossSystemContract = _worldBossSystemContract;
    }

    // 外部函数 - Boss管理
    
    /**
     * @dev 创建新Boss
     * @dev 创建具有指定属性的Boss，并设置为活跃状态
     * @param name Boss名称
     * @param description Boss描述
     * @param maxHp Boss最大生命值
     * @param level Boss等级
     * @param imageUrl Boss图片URL 1
     * @param imageUrl2 Boss图片URL 2
     * @param goldNftUrl 第一名NFT图片URL
     * @param silverNftUrl 第二名NFT图片URL
     * @param bronzeNftUrl 第三名NFT图片URL
     * @return bossId 新创建的Boss ID
     */
    function createBoss(
        string memory name,
        string memory description,
        uint256 maxHp,
        uint256 level,
        string memory imageUrl,
        string memory imageUrl2,
        string memory goldNftUrl,
        string memory silverNftUrl,
        string memory bronzeNftUrl,
        string memory _skillName
    ) external returns (uint256) {
        // 允许系统合约调用，包括WorldBossSystem主合约
        require(
            msg.sender == owner || 
            msg.sender == worldBossSystemContract || 
            msg.sender == fightRecordsContract || 
            msg.sender == userStatsContract || 
            msg.sender == nftAwardsContract,
            "Not authorized"
        );
        
        uint256 bossId = nextBossId++;
        Boss storage boss = bosses[bossId];
        
        boss.id = bossId;
        boss.name = name;
        boss.description = description;
        boss.maxHp = maxHp;
        boss.currentHp = maxHp;
        boss.level = level;
        boss.imageUrl = imageUrl;
        boss.imageUrl2 = imageUrl2;
        boss.goldNftUrl = goldNftUrl;
        boss.silverNftUrl = silverNftUrl;
        boss.bronzeNftUrl = bronzeNftUrl;
        boss.attackCount = 0;
        boss.isActive = true;
        boss.isDefeated = false;
        boss.skillName = _skillName;
        boss.respawnTime = 0;
        boss.isRespawning = false;

        emit BossCreated(bossId, name, maxHp, description, imageUrl);
        return bossId;
    }

    // 外部函数 - 战斗逻辑
    
    /**
     * @dev 检查Boss是否可被攻击
     * @dev 同时检查并处理Boss重生逻辑
     * @param bossId Boss ID
     * @return bool 如果可以攻击返回true，否则返回false
     */
    function checkCanAttack(uint256 bossId) public returns (bool) {
        Boss storage boss = bosses[bossId];
        
        // 检查是否需要重生
        checkRespawn(bossId);
        
        require(boss.isActive, "Boss not active");
        require(!boss.isDefeated, "Boss already defeated");

        return true;
    }
    
    /**
     * @dev 检查并处理Boss重生
     * @dev 如果Boss处于重生中且重生时间已到，则完成重生
     * @param bossId Boss ID
     */
    function checkRespawn(uint256 bossId) public {
        Boss storage boss = bosses[bossId];
        
        // 如果Boss正在重生中且重生时间已到
        if (boss.isRespawning && block.timestamp >= boss.respawnTime) {
            // 重生Boss
            boss.isDefeated = false;
            boss.isActive = true;
            boss.isRespawning = false;
            boss.currentHp = boss.maxHp;
            boss.attackCount = 0;
            boss.respawnTime = 0;
            
            emit BossCreated(boss.id, boss.name, boss.maxHp, boss.description, boss.imageUrl);
        }
    }
    
    /**
     * @dev 检查所有Boss的重生情况
     * @dev 批量检查所有已创建的Boss是否需要重生
     */
    function checkAllRespawns() public {
        for (uint256 i = 0; i < nextBossId; i++) {
            checkRespawn(i);
        }
    }

    /**
     * @dev 生成随机伤害值
     * @dev 伤害范围：100-500
     * @return uint256 随机伤害值
     */
    function calculateDamage() public returns (uint256) {
        // 更新随机种子
        randomSeed = uint256(keccak256(abi.encodePacked(
            randomSeed,
            block.timestamp,
            block.difficulty,
            msg.sender,
            block.number
        )));
        
        // 生成100-500之间的随机数
        return (randomSeed % 401) + 100;
    }

    /**
     * @dev 更新Boss血量
     * @dev 处理用户攻击，更新Boss状态，检查是否被击败
     * @param bossId Boss ID
     * @param damage 造成的伤害值
     * @return uint256 攻击后Boss剩余血量
     */
    function updateBossHp(uint256 bossId, address user, uint256 damage) public returns (uint256) {
        Boss storage boss = bosses[bossId];
        require(boss.isActive, "Boss not active");
        require(!boss.isDefeated, "Boss already defeated");

        // 计算新的血量
        uint256 newHp = boss.currentHp > damage ? boss.currentHp - damage : 0;
        boss.currentHp = newHp;
        boss.attackCount++;

        emit BossAttacked(user, bossId, damage, newHp);

        // 更新战斗记录
        if (fightRecordsContract != address(0)) {
            // 使用assembly调用，避免栈深度问题
            (bool success, ) = fightRecordsContract.call(
                abi.encodeWithSignature(
                    "addAttackRecord(uint256,address,uint256,uint256)",
                    bossId,
                    user,
                    damage,
                    newHp
                )
            );
        }
        
        // 更新用户统计
        if (userStatsContract != address(0)) {
            // 使用assembly调用，避免栈深度问题
            (bool success, ) = userStatsContract.call(
                abi.encodeWithSignature(
                    "updateUserStats(uint256,address,uint256)",
                    bossId,
                    user,
                    damage
                )
            );
        }

        // 检查Boss是否被击败
        if (newHp == 0) {
            boss.isDefeated = true;
            boss.isActive = false;
            // 设置10秒后重生
            boss.respawnTime = block.timestamp + 10;
            boss.isRespawning = true;
        }

        return newHp;
    }



    // 外部函数 - 查询功能
    
    /**
     * @dev 获取Boss信息
     * @param bossId Boss ID
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
    function getBossInfo(uint256 bossId) external view returns (
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
        Boss storage boss = bosses[bossId];
        return (
            boss.id,
            boss.name,
            boss.description,
            boss.maxHp,
            boss.currentHp,
            boss.level,
            boss.imageUrl,
            boss.imageUrl2,
            boss.goldNftUrl,
            boss.silverNftUrl,
            boss.bronzeNftUrl,
            boss.attackCount,
            boss.isActive,
            boss.isDefeated,
            boss.skillName
        );
    }

    /**
     * @dev 获取Boss剩余血量百分比
     * @param bossId Boss ID
     * @return uint256 血量百分比（0-100）
     */
    function getBossHpPercentage(uint256 bossId) external view returns (uint256) {
        Boss storage boss = bosses[bossId];
        if (boss.maxHp == 0) return 0;
        return (boss.currentHp * 100) / boss.maxHp;
    }

    /**
     * @dev 获取活跃Boss列表
     * @dev 返回所有未被击败且不在重生中的Boss ID
     * @return uint256[] 活跃Boss ID数组
     */
    function getActiveBosses() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // 先计算活跃Boss数量
        for (uint256 i = 0; i < nextBossId; i++) {
            Boss storage boss = bosses[i];
            if (boss.isActive && !boss.isDefeated && !boss.isRespawning) {
                activeCount++;
            }
        }
        
        // 创建结果数组
        uint256[] memory activeBosses = new uint256[](activeCount);
        uint256 index = 0;
        
        // 填充活跃Boss ID
        for (uint256 i = 0; i < nextBossId; i++) {
            Boss storage boss = bosses[i];
            if (boss.isActive && !boss.isDefeated && !boss.isRespawning) {
                activeBosses[index] = i;
                index++;
            }
        }
        
        return activeBosses;
    }
}
