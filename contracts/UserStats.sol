// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title UserStats
 * @dev 用户统计合约，用于记录和管理Boss战斗中用户的统计数据
 * 
 * 功能说明：
 * 1. 记录每个用户在特定Boss战斗中的攻击次数、总伤害和最后攻击时间
 * 2. 维护参与Boss战斗的用户列表
 * 3. 计算Boss被击败时的前三名伤害输出用户
 * 4. 提供查询用户统计数据和参与者列表的接口
 * 
 * 与其他合约的交互：
 * - BossCore: 接收攻击事件通知，更新用户统计
 * - WorldBossSystem: 提供用户统计数据用于NFT奖励分发
 */
contract UserStats {
    // 事件定义 - 用于前端监控和链下分析
    
    /** 
     * @dev 用户统计数据更新事件
     * @param user 用户地址
     * @param totalDamage 该用户在当前Boss战斗中的总伤害
     * @param attackCount 该用户在当前Boss战斗中的攻击次数
     */
    event UserStatsUpdated(address indexed user, uint256 totalDamage, uint256 attackCount);
    
    /** 
     * @dev 前三名计算完成事件
     * @param bossId Boss ID
     * @param goldWinner 金牌用户地址（第一名）
     * @param silverWinner 银牌用户地址（第二名）
     * @param bronzeWinner 铜牌用户地址（第三名）
     */
    event TopThreeCalculated(uint256 bossId, address goldWinner, address silverWinner, address bronzeWinner);

    /**
     * @dev 用户统计数据结构
     * 记录单个用户在特定Boss战斗中的战斗表现
     */
    struct UserStat {
        uint256 attackCount;      // 攻击次数
        uint256 totalDamage;      // 总伤害值
        uint256 lastAttackTime;   // 最后攻击时间（Unix时间戳）
    }

    /**
     * @dev 排名用户数据结构
     * 用于排序和查找伤害排名靠前的用户
     */
    struct RankedUser {
        address userAddress;      // 用户钱包地址
        uint256 totalDamage;      // 总伤害值
    }

    // 存储映射 - 按Boss ID和用户地址组织数据
    
    /**
     * @dev Boss战斗的用户统计映射
     * @dev 嵌套映射：第一层按Boss ID索引，第二层按用户地址索引
     * @dev 存储每个用户在每个Boss战斗中的统计数据
     */
    mapping(uint256 => mapping(address => UserStat)) private bossUserStats;
    
    /**
     * @dev 参与Boss战斗的用户列表映射
     * @dev 按Boss ID索引，存储参与特定Boss战斗的所有用户地址
     * @dev 用于快速遍历和计算排名
     */
    mapping(uint256 => address[]) private bossParticipants;
    
    /**
     * @dev 用户参与状态映射
     * @dev 按Boss ID和用户地址索引，用于快速判断用户是否已参与战斗
     * @dev 避免重复添加用户到参与者列表
     */
    mapping(uint256 => mapping(address => bool)) private isParticipant;

    // 合约状态变量
    
    /** 
     * @dev BossCore合约地址
     * @dev 用于验证调用者身份，确保只有BossCore可以更新用户统计
     */
    address public bossCoreContract;
    
    /** 
     * @dev WorldBossSystem合约地址
     * @dev 用于验证调用者身份，确保WorldBossSystem也可以调用相关函数
     */
    address public worldBossSystemContract;
    
    /** 
     * @dev 合约所有者地址
     * @dev 用于权限控制，只有所有者可以设置合约地址
     */
    address public owner;

    // 访问控制修饰符
    
    /**
     * @dev 所有者检查修饰符
     * @dev 确保只有合约部署者可以执行特定操作
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @dev 系统合约检查修饰符
     * @dev 确保只有BossCore或WorldBossSystem合约可以调用受保护的函数
     */
    modifier onlySystem() {
        require(
            msg.sender == bossCoreContract || 
            msg.sender == worldBossSystemContract,
            "Not authorized system contract"
        );
        _;
    }

    // 构造函数
    
    /**
     * @dev 构造函数，设置合约部署者为所有者
     */
    constructor() {
        owner = msg.sender;
    }

    // 外部函数 - 合约设置和管理
    
    /**
     * @dev 设置BossCore合约地址
     * @dev 只能在初始化时调用一次，用于建立合约间的关联关系
     * @param _bossCoreContract BossCore合约的地址
     */
    function setBossCoreContract(address _bossCoreContract) external onlyOwner {
        bossCoreContract = _bossCoreContract;
    }
    
    /**
     * @dev 设置WorldBossSystem合约地址
     * @param _worldBossSystemContract WorldBossSystem合约的地址
     */
    function setWorldBossSystemContract(address _worldBossSystemContract) external onlyOwner {
        worldBossSystemContract = _worldBossSystemContract;
    }

    // 外部函数 - 用户统计更新和查询
    
    /**
     * @dev 更新用户统计数据
     * @dev 由BossCore在用户攻击Boss后调用
     * @dev 如果是首次攻击，将用户添加到参与者列表
     * @param bossId Boss ID，指定是哪个Boss战斗
     * @param user 用户地址，被攻击的用户
     * @param damage 本次攻击造成的伤害值
     */
    function updateUserStats(uint256 bossId, address user, uint256 damage) external onlySystem {
        UserStat storage userStat = bossUserStats[bossId][user];
        
        // 如果是首次攻击，添加到参与者列表
        if (!isParticipant[bossId][user]) {
            bossParticipants[bossId].push(user);
            isParticipant[bossId][user] = true;
        }
        
        // 更新统计数据
        userStat.attackCount++;
        userStat.totalDamage += damage;
        userStat.lastAttackTime = block.timestamp;
        
        emit UserStatsUpdated(user, userStat.totalDamage, userStat.attackCount);
    }

    /**
     * @dev 获取用户统计数据
     * @param bossId Boss ID
     * @param user 用户地址
     * @return attackCount 攻击次数
     * @return totalDamage 总伤害值
     * @return lastAttackTime 最后攻击时间
     */
    function getUserStats(uint256 bossId, address user) external view returns (
        uint256 attackCount,
        uint256 totalDamage,
        uint256 lastAttackTime
    ) {
        UserStat storage userStat = bossUserStats[bossId][user];
        return (
            userStat.attackCount,
            userStat.totalDamage,
            userStat.lastAttackTime
        );
    }

    /**
     * @dev 获取Boss剩余血量百分比
     * @dev 注意：此函数为兼容接口保留，实际实现需要从BossCore获取数据
     * @param bossId Boss ID
     * @return 血量百分比（0-100）
     */
    function getBossHpPercentage(uint256 bossId) external view returns (uint256) {
        return 100;
    }

    /**
     * @dev 计算Boss死亡时的前三名用户
     * @dev 根据用户总伤害进行排序，返回前三名地址
     * @dev 用于NFT奖励分发
     * @param bossId Boss ID
     * @return topThree 包含前三名用户地址的数组 [金, 银, 铜]
     */
    function calculateTopThree(uint256 bossId) external onlySystem returns (address[3] memory) {
        address[] storage participants = bossParticipants[bossId];
        uint256 participantCount = participants.length;
        
        // 初始化前三名（从高到低排序：topDamages[0]为第一名）
        address[3] memory topThree;
        uint256[3] memory topDamages;
        
        // 遍历所有参与者，找出前三名
        for (uint256 i = 0; i < participantCount; i++) {
            address user = participants[i];
            uint256 damage = bossUserStats[bossId][user].totalDamage;
            
            // 检查是否能进入前三名
            if (damage > topDamages[0]) {
                // 进入第一名，其他名次后移
                topDamages[2] = topDamages[1];
                topThree[2] = topThree[1];
                
                topDamages[1] = topDamages[0];
                topThree[1] = topThree[0];
                
                topDamages[0] = damage;
                topThree[0] = user;
            } else if (damage > topDamages[1]) {
                // 进入第二名，第三名后移
                topDamages[2] = topDamages[1];
                topThree[2] = topThree[1];
                
                topDamages[1] = damage;
                topThree[1] = user;
            } else if (damage > topDamages[2]) {
                // 进入第三名
                topDamages[2] = damage;
                topThree[2] = user;
            }
        }
        
        emit TopThreeCalculated(bossId, topThree[0], topThree[1], topThree[2]);
        return topThree;
    }

    /**
     * @dev 获取参与Boss战斗的用户数量
     * @param bossId Boss ID
     * @return 参与者数量
     */
    function getParticipantCount(uint256 bossId) external view returns (uint256) {
        return bossParticipants[bossId].length;
    }

    /**
     * @dev 获取所有参与者列表
     * @param bossId Boss ID
     * @return 参与者地址数组
     */
    function getAllParticipants(uint256 bossId) external view returns (address[] memory) {
        return bossParticipants[bossId];
    }

    /**
     * @dev 获取Boss的总伤害
     * @dev 计算所有参与者对特定Boss造成的总伤害
     * @param bossId Boss ID
     * @return totalDamage 总伤害值
     */
    function getTotalDamage(uint256 bossId) external view returns (uint256) {
        address[] storage participants = bossParticipants[bossId];
        uint256 totalDamage = 0;
        
        for (uint256 i = 0; i < participants.length; i++) {
            totalDamage += bossUserStats[bossId][participants[i]].totalDamage;
        }
        
        return totalDamage;
    }
}
