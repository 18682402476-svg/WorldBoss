// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title FightRecords
 * @dev 战斗记录合约，用于记录和管理Boss战斗的详细信息
 * 
 * 功能说明：
 * 1. 记录每次攻击的详细信息（攻击者、伤害、时间戳等）
 * 2. 记录Boss技能触发和结束事件
 * 3. 提供高效的历史记录查询功能
 * 4. 限制单次查询最多返回30条记录（高并发优化）
 * 
 * 记录类型：
 * - Attack: 用户对Boss的普通攻击
 * - Skill: Boss技能触发事件
 * - SkillEnd: Boss技能结束事件
 * 
 * 数据结构优化：
 * - 使用动态数组存储每个Boss的战斗记录
 * - 维护记录计数器以快速获取总数
 * - 限制查询数量以防止恶意查询导致 gas 消耗过高
 * 
 * 与其他合约的交互：
 * - BossCore: 接收攻击和技能事件，记录详细信息
 * - WorldBossSystem: 提供战斗记录查询接口给前端展示
 */
contract FightRecords {
    
    // 事件定义 - 用于前端监控和链下分析
    
    /** 
     * @dev 攻击记录添加事件
     * @param bossId Boss ID
     * @param attacker 攻击者地址
     * @param damage 造成的伤害值
     */
    event AttackRecordAdded(uint256 indexed bossId, address indexed attacker, uint256 damage);
    
    /** 
     * @dev 技能记录添加事件
     * @param bossId Boss ID
     * @param skillName 技能名称
     */
    event SkillRecordAdded(uint256 indexed bossId, string skillName);
    
    /** 
     * @dev 技能结束记录添加事件
     * @param bossId Boss ID
     * @param skillName 技能名称
     */
    event SkillEndRecordAdded(uint256 indexed bossId, string skillName);

    // 数据结构定义
    
    /**
     * @dev 记录类型枚举
     * @dev 用于区分不同类型的战斗事件
     */
    enum RecordType {
        Attack,      // 普通攻击
        Skill,       // 技能触发
        SkillEnd     // 技能结束
    }

    /**
     * @dev 战斗记录数据结构
     * @dev 存储单次战斗事件的详细信息
     */
    struct AttackRecord {
        address attacker;        // 攻击者地址（技能事件为address(0)）
        uint256 timestamp;       // 事件发生时间（Unix时间戳）
        uint256 damage;          // 造成的伤害（技能事件为0）
        uint256 bossHpAfter;     // 攻击后Boss血量
        RecordType recordType;   // 记录类型
        string skillName;        // 技能名称（普通攻击为空）
    }

    // 存储映射
    
    /**
     * @dev Boss战斗记录映射
     * @dev 按Boss ID索引，存储该Boss的所有战斗记录
     * @dev 使用动态数组，支持无限条记录
     */
    mapping(uint256 => AttackRecord[]) private bossRecords;
    
    /**
     * @dev 记录总数映射
     * @dev 按Boss ID索引，快速获取该Boss的战斗记录总数
     * @dev 用于边界检查和分页查询
     */
    mapping(uint256 => uint256) private bossRecordCounts;

    // 合约状态变量
    
    /**
     * @dev BossCore合约地址
     * @dev 用于验证调用者身份，确保只有BossCore可以添加记录
     */
    address public bossCoreContract;
    
    /**
     * @dev 合约所有者地址
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

    /**
     * @dev 系统合约检查修饰符
     */
    modifier onlySystem() {
        require(msg.sender == bossCoreContract, "Not authorized system contract");
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

    // 外部函数 - 合约设置
    
    /**
     * @dev 设置BossCore合约地址
     * @param _bossCoreContract BossCore合约的地址
     */
    function setBossCoreContract(address _bossCoreContract) external onlyOwner {
        bossCoreContract = _bossCoreContract;
    }

    // 外部函数 - 记录管理
    
    /**
     * @dev 添加攻击记录
     * @dev 当用户攻击Boss时调用，记录攻击详情
     * @param bossId Boss ID
     * @param attacker 攻击者地址
     * @param damage 造成的伤害值
     * @param bossHpAfter 攻击后Boss剩余血量
     */
    function addAttackRecord(
        uint256 bossId,
        address attacker,
        uint256 damage,
        uint256 bossHpAfter
    ) external onlySystem {
        AttackRecord memory record = AttackRecord({
            attacker: attacker,
            timestamp: block.timestamp,
            damage: damage,
            bossHpAfter: bossHpAfter,
            recordType: RecordType.Attack,
            skillName: ""
        });

        bossRecords[bossId].push(record);
        bossRecordCounts[bossId]++;

        emit AttackRecordAdded(bossId, attacker, damage);
    }

    /**
     * @dev 添加技能释放记录
     * @dev 当Boss技能被触发时调用
     * @param bossId Boss ID
     * @param skillName 技能名称
     */
    function addSkillRecord(
        uint256 bossId,
        string memory skillName
    ) external onlySystem {
        AttackRecord memory record = AttackRecord({
            attacker: address(0), // 技能释放不是用户攻击
            timestamp: block.timestamp,
            damage: 0,
            bossHpAfter: 0, // 技能释放不影响血量
            recordType: RecordType.Skill,
            skillName: skillName
        });

        bossRecords[bossId].push(record);
        bossRecordCounts[bossId]++;

        emit SkillRecordAdded(bossId, skillName);
    }

    /**
     * @dev 添加技能结束记录
     * @dev 当Boss技能结束时调用
     * @param bossId Boss ID
     * @param skillName 技能名称
     */
    function addSkillEndRecord(
        uint256 bossId,
        string memory skillName
    ) external onlySystem {
        AttackRecord memory record = AttackRecord({
            attacker: address(0),
            timestamp: block.timestamp,
            damage: 0,
            bossHpAfter: 0,
            recordType: RecordType.SkillEnd,
            skillName: skillName
        });

        bossRecords[bossId].push(record);
        bossRecordCounts[bossId]++;

        emit SkillEndRecordAdded(bossId, skillName);
    }

    // 外部函数 - 查询功能
    
    /**
     * @dev 获取Boss的最新攻击记录
     * @dev 高并发优化：限制单次查询最多30条记录
     * @param bossId Boss ID
     * @param count 要查询的记录数量（最大30）
     * @return AttackRecord[] 最新的攻击记录数组（按时间倒序）
     */
    function getLatestAttackRecords(uint256 bossId, uint256 count) external view returns (AttackRecord[] memory) {
        require(count <= 30, "Can only query up to 30 records");
        
        uint256 totalRecords = bossRecordCounts[bossId];
        uint256 actualCount = count;
        
        if (totalRecords < count) {
            actualCount = totalRecords;
        }
        
        AttackRecord[] memory result = new AttackRecord[](actualCount);
        AttackRecord[] storage allRecords = bossRecords[bossId];
        
        uint256 startIndex = totalRecords - actualCount;
        
        for (uint256 i = 0; i < actualCount; i++) {
            result[i] = allRecords[startIndex + i];
        }
        
        return result;
    }

    /**
     * @dev 获取Boss的战斗记录总数
     * @param bossId Boss ID
     * @return uint256 记录总数
     */
    function getRecordCount(uint256 bossId) external view returns (uint256) {
        return bossRecordCounts[bossId];
    }

    /**
     * @dev 获取特定索引的记录
     * @param bossId Boss ID
     * @param recordIndex 记录索引（0开始）
     * @return AttackRecord 指定的战斗记录
     */
    function getRecord(uint256 bossId, uint256 recordIndex) external view returns (AttackRecord memory) {
        require(recordIndex < bossRecordCounts[bossId], "Record index out of range");
        return bossRecords[bossId][recordIndex];
    }
}
