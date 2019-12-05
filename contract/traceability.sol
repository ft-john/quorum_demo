pragma solidity >=0.4.0 <0.7.0;

//支持在方法中返回数组与结构体等类型
pragma experimental ABIEncoderV2;

contract traceability {
    // 资产动态属性
    struct MetadataMapping {
        string[] keys;
        mapping(string => string) metadata;
    }

    struct Asset {
        // 资产id
        bytes32 id;
        // 资产名称
        string name;
        // 当前拥有人
        address ownership;
        // 资产其他动态属性
        MetadataMapping metadata;
    }

    struct Batch {
        bytes32 id;
        // 发货方
        address sender;
        // 物流方
        address transporter;
        // 收货方
        address receiver;
        // 物流费用，可选
        uint shipReward;
        //token转移数量，可选
        uint tokenReward;
        // 状态，1-Created, 2-sent, 3-logisticReceived, 4-logisticSent, 5-received
        uint status;
        // 发货时间
        uint256 sendTime;
        // 物流收货时间
        uint256 logisticReceiveTime;
        // 物流发货时间
        uint256 logisticSendTime;
        // 收货时间
        uint256 receiveTime;
        // 包含的资产明细id
        bytes32[] assetList;
    }

    // 资产历史动态追踪
    struct Track {
        bytes32 id;
        // 资产id
        bytes32 assetId;
        // 当前拥有人
        address ownership;
        // 当前动态，1-CreateAsset, 2-CreateBatch, 3-Send, 4-LogisticReceive, 5-LogisticSend, 6-Receive
        uint action;
        // 备注
        bytes remark;
        // 动态发生时间
        uint256 timestamp;
    }

    // 初始发币金额
    uint constant initTokens = 1 * 1e6 * 1e18;
    // 合约管理员-初始发币接收人
    address public admin;

    uint public assetSize;
    uint public batchSize;
    uint public trackSize;
    bytes32[] public assetIds;
    mapping (address => uint) balances;
    mapping(bytes32 => Asset) assets;
    mapping(bytes32 => Batch) batches;
    mapping(bytes32 => Track) tracks;
    mapping(bytes32 => bytes32[]) assetTrackIds;

    event TokenSent(address from, address to, uint amount);
    event AssetCreated(address ownership, bytes32 assetId);
    event BatchCreated(address sender, bytes32 batchId);
    event BatchSent(address sender, bytes32 batchId);
    event BatchReceived(address receiver, bytes32 batchId);

    bytes empty;

    constructor() public {
        admin = msg.sender;
        balances[admin] = initTokens;
    }

    /// @notice token转账
    /// @param receiver 收款人
    /// @param amount 转账金额
    function sendToken(address receiver, uint amount) public {
        require(amount <= balances[msg.sender], "Insufficient balance.");

        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit TokenSent(msg.sender, receiver, amount);
    }

    /// @notice 获取当前账户token余额
    /// @return 当前余额
    function getBalance() public view returns (uint) {
        return balances[msg.sender];
    }

    /// @notice 创建资产
    /// @param name 资产名称
    /// @param keys 动态属性名
    /// @param values 动态属性值
    /// @return 新资产id
    function createAsset(string memory name, string[] memory keys, string[] memory values) public returns (bytes32) {
        require(keys.length == values.length, "keys and values not matched");

        bytes32 id = getUniqueId(1, assetSize, msg.sender);
        assets[id].id = id;
        assets[id].name = name;
        assets[id].ownership = msg.sender;
        assets[id].metadata.keys = keys;
        assetSize ++;

        for(uint i = 0; i < keys.length; i ++) {
            assets[id].metadata.metadata[keys[i]] = values[i];
        }

        assetIds.push(id);
        saveTrack(id, msg.sender, 1, empty);
        emit AssetCreated(msg.sender, id);
        return id;
    }

    /// @notice 创建batch
    /// @param transporter 物流方地址
    /// @param receiver 收货方地址
    /// @param shipReward 物流费用，可为0
    /// @param tokenReward Token转移金额，可为0
    /// @param assetList 资产明细id
    /// @return batch id
    function createBatch(address transporter, address receiver, uint shipReward, uint tokenReward, bytes32[] memory assetList) public returns (bytes32) {
        require((shipReward + tokenReward) <= balances[msg.sender], "Insufficient balance.");

        bytes32 id = getUniqueId(2, batchSize, msg.sender);
        batches[id] = Batch(id, msg.sender, transporter, receiver, shipReward, tokenReward, 1, now, 0, 0, 0, assetList);
        batchSize ++;
        balances[msg.sender] -= (shipReward + tokenReward);

        for(uint i = 0; i < assetList.length; i ++) {
            require(assets[assetList[i]].ownership == msg.sender, "Insufficient assets privileges");
            saveTrack(assetList[i], msg.sender, 2, abi.encodePacked(id));
        }

        emit BatchCreated(msg.sender, id);
        return id;
    }

    /// @notice 发送batch
    /// @notice 可以直接发送给 batch中的transporter或receiver，batch直接从sender发给receiver表示不走物流
    /// @param batchId batch id
    /// @param receiver 收货方，可以为batch中的transporter或receiver
    function sendBatch(bytes32 batchId, address receiver) public {
        Batch storage batch = batches[batchId];

        require((batch.status >= 1 && batch.status <= 5), "Batch not found");
        require((batch.status == 1 || batch.status == 3), "Batch cannot be sent");

        if(batch.status == 1) {
            require(msg.sender == batch.sender, "Insufficient privileges");
            require(receiver == batch.transporter || receiver == batch.receiver, "Receiver invalid");
            
            if(receiver == batch.transporter) {
                batch.status ++;
                batch.sendTime = now;
    
                for(uint i = 0; i < batch.assetList.length; i ++) {
                    saveTrack(batch.assetList[i], msg.sender, 3, abi.encodePacked(batch.id));
                }                
            } else {
                batch.status = 4;
                batch.sendTime = now;
    
                for(uint i = 0; i < batch.assetList.length; i ++) {
                    saveTrack(batch.assetList[i], msg.sender, 5, abi.encodePacked(batch.id));
                }                
            }
        } else {
            require(receiver == batch.receiver, "Insufficient privileges");
            batch.status ++;
            batch.logisticSendTime = now;

            for(uint i = 0; i < batch.assetList.length; i ++) {
                saveTrack(batch.assetList[i], msg.sender, 5, abi.encodePacked(batch.id));
            }
        }

        emit BatchSent(msg.sender, batch.id);
    }

    /// @notice 接收batch,如果当前用户是batch的transporter表示物流收货，如果是receiver表示batch成功转移到最终用户
    /// @param batchId batch id 
    function receiveBatch(bytes32 batchId) public {
        Batch storage batch = batches[batchId];

        require((batch.status >= 1 && batch.status <= 5), "Batch not found");
        require((batch.status == 2 || batch.status == 4), "Batch cannot be received");

        if(batch.status == 2) {
            require(msg.sender == batch.transporter, "Insufficient privileges");

            batch.status ++;
            batch.logisticReceiveTime = now;
            balances[msg.sender] += batch.shipReward;

            for(uint i = 0; i < batch.assetList.length; i ++) {
                saveTrack(batch.assetList[i], msg.sender, 4, abi.encodePacked(batch.id));
            }
        } else {
            require(msg.sender == batch.receiver, "Insufficient privileges");
            batch.status ++;
            batch.receiveTime = now;
            balances[msg.sender] += batch.tokenReward;

            for(uint i = 0; i < batch.assetList.length; i ++) {
                assets[batch.assetList[i]].ownership = msg.sender;
                saveTrack(batch.assetList[i], msg.sender, 6, abi.encodePacked(batch.id));
            }
        }

        emit BatchReceived(msg.sender, batch.id);
    }

    /// @notice 获取当前用户下面的资产列表
    /// @return 资产id集合
    function getAssetList() public view returns (bytes32[] memory) {
        //目前实现方案效率不高，需继续优化
        uint size;
        for(uint i = 0; i < assetIds.length; i ++) {
            if(assets[assetIds[i]].ownership == msg.sender) {
                size ++;
            }
        }

        bytes32[] memory ids = new bytes32[](size);
        uint index = 0;
        for(uint i = 0; i < assetIds.length; i ++) {
            if(assets[assetIds[i]].ownership == msg.sender) {
                ids[index] = assetIds[i];
                index ++;
            }
        }
        return ids;
    }

    /// @notice 根据assetId获取资产信息
    /// @param assetId 资产id
    /// @return 资产id，资产名称，拥有人地址，动态属性名集合，动态属性值集合 
    function getAssetInfo(bytes32 assetId) public view returns (bytes32, string memory, address, string[] memory, string[] memory) {
        Asset storage asset = assets[assetId];
        string[] memory values = new string[](asset.metadata.keys.length);

        for(uint i = 0; i < asset.metadata.keys.length; i ++) {
            string memory value = asset.metadata.metadata[asset.metadata.keys[i]];
            values[i] = value;
        }

        return (asset.id, asset.name, asset.ownership, asset.metadata.keys, values);
    }
    
    /// @notice 获取batch详情-包括最新的状态
    /// @param batchId batch id
    /// @return batch详情
    function getBatchInfo(bytes32 batchId) public view returns(Batch memory) {
        return batches[batchId];
    }

    /// @notice 内部方法-保存资产历史动态
    function saveTrack(bytes32 assetId, address owner, uint action, bytes memory remark) private {
        bytes32 id = getUniqueId(3, trackSize, owner);
        tracks[id] = Track(id, assetId, owner, action, remark, now);
        assetTrackIds[assetId].push(id);
        trackSize ++;
    }

    /// @notice 内部方法-生成唯一id
    function getUniqueId(uint typeId, uint nonce, address owner) private pure returns (bytes32) {
        return keccak256(abi.encode(typeId, nonce, owner));
    }
}