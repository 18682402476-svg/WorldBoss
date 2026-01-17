// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftAwards is ERC721, ERC721URIStorage, Ownable {
    
    /**
     * @dev 解决supportsInterface函数冲突
     * @dev ERC721和ERC721URIStorage都实现了supportsInterface，需要显式指定继承链
     * @param interfaceId 接口ID
     * @return bool 是否支持该接口
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    // 事件定义 - 用于前端监控和链下分析
    
    /** 
     * @dev NFT铸造事件
     * @param winner 获奖用户地址
     * @param tokenId 铸造的NFT Token ID
     * @param awardType 奖励类型字符串（"Gold"、"Silver"、"Bronze"）
     */
    event AwardMinted(address indexed winner, uint256 indexed tokenId, string awardType);
    
    /** 
     * @dev Boss奖励发放完成事件
     * @param bossId Boss ID
     * @param goldWinner 金牌获得者地址
     * @param silverWinner 银牌获得者地址
     * @param bronzeWinner 铜牌获得者地址
     */
    event BossAwardsDistributed(uint256 bossId, address goldWinner, address silverWinner, address bronzeWinner);

    // 数据结构定义
    
    /**
     * @dev 奖励类型枚举
     * @dev 定义三种NFT奖励等级
     */
    enum AwardType {
        Gold,       // 金牌 - 第一名
        Silver,     // 银牌 - 第二名
        Bronze      // 铜牌 - 第三名
    }

    // 存储映射
    
    /**
     * @dev NFT元数据URI映射
     * @dev 按奖励类型存储对应的NFT元数据URI
     * @dev Gold对应金牌URI，Silver对应银牌URI，Bronze对应铜牌URI
     */
    mapping(AwardType => string) private awardURIs;
    
    /**
     * @dev Boss奖励发放记录映射
     * @dev 按Boss ID索引，记录每个Boss的奖励是否已发放
     * @dev 用于防止同一Boss的奖励被重复发放
     */
    mapping(uint256 => bool) private bossAwardsDistributed;

    // 合约状态变量
    
    /**
     * @dev 下一个NFT Token ID
     * @dev 从1开始递增，确保每个NFT都有唯一的ID
     */
    uint256 private nextTokenId;
    
    /**
     * @dev BossCore合约地址
     * @dev 用于验证调用者身份，确保只有授权的系统合约可以发放NFT
     */
    address public bossCoreContract;
    
    /**
     * @dev WorldBossSystem合约地址
     * @dev 用于验证调用者身份，确保只有授权的系统合约可以发放NFT
     */
    address public worldBossSystemContract;

    // 访问控制修饰符
    
    /**
     * @dev 系统合约检查修饰符
     * @dev 确保只有授权的系统合约可以调用NFT铸造和发放函数
     */
    modifier onlySystem() {
        require(
            msg.sender == bossCoreContract || 
            msg.sender == worldBossSystemContract,
            "Not authorized system contract"
        );
        _;
    }

    // 外部函数 - 合约设置
    
    /**
     * @dev 设置WorldBossSystem合约地址
     * @param _worldBossSystemContract WorldBossSystem合约的地址
     */
    function setWorldBossSystemContract(address _worldBossSystemContract) external onlyOwner {
        worldBossSystemContract = _worldBossSystemContract;
    }

    // 构造函数
    
    /**
     * @dev 构造函数
     * @dev 初始化NFT合约的名称和符号，并设置起始Token ID
     * @dev 合约名称：WorldBossAwards (WBA)
     */
    constructor() ERC721("WorldBossAwards", "WBA") {
        nextTokenId = 1;
    }

    // 外部函数 - 合约设置和管理
    
    /**
     * @dev 设置BossCore合约地址
     * @dev 只能在初始化时调用一次，用于建立合约间的关联关系
     * @dev 后续BossCore可以通过此地址调用本合约的NFT发放功能
     * @param _bossCoreContract BossCore合约的地址
     */
    function setBossCoreContract(address _bossCoreContract) external onlyOwner {
        bossCoreContract = _bossCoreContract;
    }

    /**
     * @dev 设置奖励NFT的元数据URI
     * @dev 所有者可以为每种奖励类型设置对应的元数据URI
     * @dev URI通常指向IPFS或其他去中心化存储上的JSON元数据
     * @param awardType 奖励类型（Gold/Silver/Bronze）
     * @param uri 元数据URI字符串
     */
    function setAwardURI(AwardType awardType, string calldata uri) external onlyOwner {
        awardURIs[awardType] = uri;
    }

    // 外部函数 - NFT铸造和发放
    
    /**
     * @dev 铸造奖励NFT（使用固定URI）
     * @dev 为指定用户铸造特定类型的奖励NFT
     * @dev 内部调用ERC721的_safeMint和_setTokenURI完成铸造
     * @param to 获奖用户地址（NFT接收者）
     * @param awardType 奖励类型（Gold/Silver/Bronze）
     * @return tokenId 铸造的NFT Token ID
     */
    function mintAward(address to, AwardType awardType) public onlySystem returns (uint256) {
        uint256 tokenId = nextTokenId++;
        string memory uri = awardURIs[awardType];
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        string memory awardTypeStr;
        if (awardType == AwardType.Gold) {
            awardTypeStr = "Gold";
        } else if (awardType == AwardType.Silver) {
            awardTypeStr = "Silver";
        } else {
            awardTypeStr = "Bronze";
        }
        
        emit AwardMinted(to, tokenId, awardTypeStr);
        return tokenId;
    }

    /**
     * @dev 铸造奖励NFT（使用自定义URI）
     * @dev 为指定用户铸造特定类型的奖励NFT，使用传入的自定义URI
     * @param to 获奖用户地址（NFT接收者）
     * @param awardType 奖励类型（Gold/Silver/Bronze）
     * @param uri 自定义NFT元数据URI
     * @return tokenId 铸造的NFT Token ID
     */
    function mintAwardWithUri(address to, AwardType awardType, string calldata uri) public onlySystem returns (uint256) {
        uint256 tokenId = nextTokenId++;
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        string memory awardTypeStr;
        if (awardType == AwardType.Gold) {
            awardTypeStr = "Gold";
        } else if (awardType == AwardType.Silver) {
            awardTypeStr = "Silver";
        } else {
            awardTypeStr = "Bronze";
        }
        
        emit AwardMinted(to, tokenId, awardTypeStr);
        return tokenId;
    }

    /**
     * @dev 发放Boss战斗奖励
     * @dev 为Boss战斗的前三名用户铸造并发放对应的NFT
     * @dev 包含防重复发放检查，确保每个Boss只发放一次奖励
     * @param bossId Boss ID，指定是哪个Boss战斗的奖励
     * @param goldWinner 金牌获得者地址（伤害第一名）
     * @param silverWinner 银牌获得者地址（伤害第二名）
     * @param bronzeWinner 铜牌获得者地址（伤害第三名）
     */
    function distributeBossAwards(
        uint256 bossId,
        address goldWinner,
        address silverWinner,
        address bronzeWinner
    ) external onlySystem {
        require(!bossAwardsDistributed[bossId], "Awards already distributed for this boss");
        
        // 为前三名用户铸造NFT
        if (goldWinner != address(0)) {
            mintAward(goldWinner, AwardType.Gold);
        }
        if (silverWinner != address(0)) {
            mintAward(silverWinner, AwardType.Silver);
        }
        if (bronzeWinner != address(0)) {
            mintAward(bronzeWinner, AwardType.Bronze);
        }
        
        bossAwardsDistributed[bossId] = true;
        
        emit BossAwardsDistributed(bossId, goldWinner, silverWinner, bronzeWinner);
    }

    // 外部函数 - 查询功能
    
    /**
     * @dev 检查Boss奖励是否已发放
     * @param bossId Boss ID
     * @return bool 如果已发放返回true，否则返回false
     */
    function areBossAwardsDistributed(uint256 bossId) external view returns (bool) {
        return bossAwardsDistributed[bossId];
    }

    // 内部函数 - ERC721兼容性
    
    /**
     * @dev 销毁NFT
     * @dev 重写_burn函数以支持ERC721URIStorage
     * @dev 注意：此函数在当前设计中未使用，保留用于兼容性
     * @param tokenId 要销毁的NFT Token ID
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
     * @dev 获取NFT元数据URI
     * @dev 重写tokenURI函数以支持ERC721URIStorage
     * @param tokenId NFT Token ID
     * @return string 该NFT的元数据URI
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
