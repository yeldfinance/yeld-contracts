pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


contract solcChecker {
 function f(bytes calldata x) external;
}

contract ProvableI {

    address public cbAddress;

    function setProofType(byte _proofType) external;
    function setCustomGasPrice(uint _gasPrice) external;
    function getPrice(string memory _datasource) public returns (uint _dsprice);
    function randomDS_getSessionPubKeyHash() external view returns (bytes32 _sessionKeyHash);
    function getPrice(string memory _datasource, uint _gasLimit) public returns (uint _dsprice);
    function queryN(uint _timestamp, string memory _datasource, bytes memory _argN) public payable returns (bytes32 _id);
    function query(uint _timestamp, string calldata _datasource, string calldata _arg) external payable returns (bytes32 _id);
    function query2(uint _timestamp, string memory _datasource, string memory _arg1, string memory _arg2) public payable returns (bytes32 _id);
    function query_withGasLimit(uint _timestamp, string calldata _datasource, string calldata _arg, uint _gasLimit) external payable returns (bytes32 _id);
    function queryN_withGasLimit(uint _timestamp, string calldata _datasource, bytes calldata _argN, uint _gasLimit) external payable returns (bytes32 _id);
    function query2_withGasLimit(uint _timestamp, string calldata _datasource, string calldata _arg1, string calldata _arg2, uint _gasLimit) external payable returns (bytes32 _id);
}

contract OracleAddrResolverI {
    function getAddress() public returns (address _address);
}

library Buffer {

    struct buffer {
        bytes buf;
        uint capacity;
    }

    function init(buffer memory _buf, uint _capacity) internal pure {
        uint capacity = _capacity;
        if (capacity % 32 != 0) {
            capacity += 32 - (capacity % 32);
        }
        _buf.capacity = capacity; 
        assembly {
            let ptr := mload(0x40)
            mstore(_buf, ptr)
            mstore(ptr, 0)
            mstore(0x40, add(ptr, capacity))
        }
    }

    function resize(buffer memory _buf, uint _capacity) private pure {
        bytes memory oldbuf = _buf.buf;
        init(_buf, _capacity);
        append(_buf, oldbuf);
    }

    function max(uint _a, uint _b) private pure returns (uint _max) {
        if (_a > _b) {
            return _a;
        }
        return _b;
    }
    
    function append(buffer memory _buf, bytes memory _data) internal pure returns (buffer memory _buffer) {
        if (_data.length + _buf.buf.length > _buf.capacity) {
            resize(_buf, max(_buf.capacity, _data.length) * 2);
        }
        uint dest;
        uint src;
        uint len = _data.length;
        assembly {
            let bufptr := mload(_buf) 
            let buflen := mload(bufptr) 
            dest := add(add(bufptr, buflen), 32) 
            mstore(bufptr, add(buflen, mload(_data))) 
            src := add(_data, 32)
        }
        for(; len >= 32; len -= 32) { 
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }
        uint mask = 256 ** (32 - len) - 1; 
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
        return _buf;
    }
    
    function append(buffer memory _buf, uint8 _data) internal pure {
        if (_buf.buf.length + 1 > _buf.capacity) {
            resize(_buf, _buf.capacity * 2);
        }
        assembly {
            let bufptr := mload(_buf) 
            let buflen := mload(bufptr) 
            let dest := add(add(bufptr, buflen), 32) 
            mstore8(dest, _data)
            mstore(bufptr, add(buflen, 1)) 
        }
    }
    
    function appendInt(buffer memory _buf, uint _data, uint _len) internal pure returns (buffer memory _buffer) {
        if (_len + _buf.buf.length > _buf.capacity) {
            resize(_buf, max(_buf.capacity, _len) * 2);
        }
        uint mask = 256 ** _len - 1;
        assembly {
            let bufptr := mload(_buf) 
            let buflen := mload(bufptr) 
            let dest := add(add(bufptr, buflen), _len) 
            mstore(dest, or(and(mload(dest), not(mask)), _data))
            mstore(bufptr, add(buflen, _len)) 
        }
        return _buf;
    }
}

library CBOR {

    using Buffer for Buffer.buffer;

    uint8 private constant MAJOR_TYPE_INT = 0;
    uint8 private constant MAJOR_TYPE_MAP = 5;
    uint8 private constant MAJOR_TYPE_BYTES = 2;
    uint8 private constant MAJOR_TYPE_ARRAY = 4;
    uint8 private constant MAJOR_TYPE_STRING = 3;
    uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
    uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

    function encodeType(Buffer.buffer memory _buf, uint8 _major, uint _value) private pure {
        if (_value <= 23) {
            _buf.append(uint8((_major << 5) | _value));
        } else if (_value <= 0xFF) {
            _buf.append(uint8((_major << 5) | 24));
            _buf.appendInt(_value, 1);
        } else if (_value <= 0xFFFF) {
            _buf.append(uint8((_major << 5) | 25));
            _buf.appendInt(_value, 2);
        } else if (_value <= 0xFFFFFFFF) {
            _buf.append(uint8((_major << 5) | 26));
            _buf.appendInt(_value, 4);
        } else if (_value <= 0xFFFFFFFFFFFFFFFF) {
            _buf.append(uint8((_major << 5) | 27));
            _buf.appendInt(_value, 8);
        }
    }

    function encodeIndefiniteLengthType(Buffer.buffer memory _buf, uint8 _major) private pure {
        _buf.append(uint8((_major << 5) | 31));
    }

    function encodeUInt(Buffer.buffer memory _buf, uint _value) internal pure {
        encodeType(_buf, MAJOR_TYPE_INT, _value);
    }

    function encodeInt(Buffer.buffer memory _buf, int _value) internal pure {
        if (_value >= 0) {
            encodeType(_buf, MAJOR_TYPE_INT, uint(_value));
        } else {
            encodeType(_buf, MAJOR_TYPE_NEGATIVE_INT, uint(-1 - _value));
        }
    }

    function encodeBytes(Buffer.buffer memory _buf, bytes memory _value) internal pure {
        encodeType(_buf, MAJOR_TYPE_BYTES, _value.length);
        _buf.append(_value);
    }

    function encodeString(Buffer.buffer memory _buf, string memory _value) internal pure {
        encodeType(_buf, MAJOR_TYPE_STRING, bytes(_value).length);
        _buf.append(bytes(_value));
    }

    function startArray(Buffer.buffer memory _buf) internal pure {
        encodeIndefiniteLengthType(_buf, MAJOR_TYPE_ARRAY);
    }

    function startMap(Buffer.buffer memory _buf) internal pure {
        encodeIndefiniteLengthType(_buf, MAJOR_TYPE_MAP);
    }

    function endSequence(Buffer.buffer memory _buf) internal pure {
        encodeIndefiniteLengthType(_buf, MAJOR_TYPE_CONTENT_FREE);
    }
}

contract usingProvable {

    using CBOR for Buffer.buffer;

    ProvableI provable;
    OracleAddrResolverI OAR;

    uint constant day = 60 * 60 * 24;
    uint constant week = 60 * 60 * 24 * 7;
    uint constant month = 60 * 60 * 24 * 30;

    byte constant proofType_NONE = 0x00;
    byte constant proofType_Ledger = 0x30;
    byte constant proofType_Native = 0xF0;
    byte constant proofStorage_IPFS = 0x01;
    byte constant proofType_Android = 0x40;
    byte constant proofType_TLSNotary = 0x10;

    string provable_network_name;
    uint8 constant networkID_auto = 0;
    uint8 constant networkID_morden = 2;
    uint8 constant networkID_mainnet = 1;
    uint8 constant networkID_testnet = 2;
    uint8 constant networkID_consensys = 161;

    mapping(bytes32 => bytes32) provable_randomDS_args;
    mapping(bytes32 => bool) provable_randomDS_sessionKeysHashVerified;

    modifier provableAPI {
        if ((address(OAR) == address(0)) || (getCodeSize(address(OAR)) == 0)) {
            provable_setNetwork(networkID_auto);
        }
        if (address(provable) != OAR.getAddress()) {
            provable = ProvableI(OAR.getAddress());
        }
        _;
    }

    modifier provable_randomDS_proofVerify(bytes32 _queryId, string memory _result, bytes memory _proof) {
        
        require((_proof[0] == "L") && (_proof[1] == "P") && (uint8(_proof[2]) == uint8(1)));
        bool proofVerified = provable_randomDS_proofVerify__main(_proof, _queryId, bytes(_result), provable_getNetworkName());
        require(proofVerified);
        _;
    }

    function provable_setNetwork(uint8 _networkID) internal returns (bool _networkSet) {
      _networkID; 
      return provable_setNetwork();
    }

    function provable_setNetworkName(string memory _network_name) internal {
        provable_network_name = _network_name;
    }

    function provable_getNetworkName() internal view returns (string memory _networkName) {
        return provable_network_name;
    }

    function provable_setNetwork() internal returns (bool _networkSet) {
        if (getCodeSize(0x1d3B2638a7cC9f2CB3D298A3DA7a90B67E5506ed) > 0) { 
            OAR = OracleAddrResolverI(0x1d3B2638a7cC9f2CB3D298A3DA7a90B67E5506ed);
            provable_setNetworkName("eth_mainnet");
            return true;
        }
        if (getCodeSize(0xc03A2615D5efaf5F49F60B7BB6583eaec212fdf1) > 0) { 
            OAR = OracleAddrResolverI(0xc03A2615D5efaf5F49F60B7BB6583eaec212fdf1);
            provable_setNetworkName("eth_ropsten3");
            return true;
        }
        if (getCodeSize(0xB7A07BcF2Ba2f2703b24C0691b5278999C59AC7e) > 0) { 
            OAR = OracleAddrResolverI(0xB7A07BcF2Ba2f2703b24C0691b5278999C59AC7e);
            provable_setNetworkName("eth_kovan");
            return true;
        }
        if (getCodeSize(0x146500cfd35B22E4A392Fe0aDc06De1a1368Ed48) > 0) { 
            OAR = OracleAddrResolverI(0x146500cfd35B22E4A392Fe0aDc06De1a1368Ed48);
            provable_setNetworkName("eth_rinkeby");
            return true;
        }
        if (getCodeSize(0xa2998EFD205FB9D4B4963aFb70778D6354ad3A41) > 0) { 
            OAR = OracleAddrResolverI(0xa2998EFD205FB9D4B4963aFb70778D6354ad3A41);
            provable_setNetworkName("eth_goerli");
            return true;
        }
        if (getCodeSize(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475) > 0) { 
            OAR = OracleAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
            return true;
        }
        if (getCodeSize(0x20e12A1F859B3FeaE5Fb2A0A32C18F5a65555bBF) > 0) { 
            OAR = OracleAddrResolverI(0x20e12A1F859B3FeaE5Fb2A0A32C18F5a65555bBF);
            return true;
        }
        if (getCodeSize(0x51efaF4c8B3C9AfBD5aB9F4bbC82784Ab6ef8fAA) > 0) { 
            OAR = OracleAddrResolverI(0x51efaF4c8B3C9AfBD5aB9F4bbC82784Ab6ef8fAA);
            return true;
        }
        return false;
    }
    
    function __callback(bytes32 _myid, string memory _result) public {
        __callback(_myid, _result, new bytes(0));
    }

    function __callback(bytes32 _myid, string memory _result, bytes memory _proof) public {
      _myid; _result; _proof;
      provable_randomDS_args[bytes32(0)] = bytes32(0);
    }

    function provable_getPrice(string memory _datasource) provableAPI internal returns (uint _queryPrice) {
        return provable.getPrice(_datasource);
    }

    function provable_getPrice(string memory _datasource, uint _gasLimit) provableAPI internal returns (uint _queryPrice) {
        return provable.getPrice(_datasource, _gasLimit);
    }

    function provable_query(string memory _datasource, string memory _arg) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        return provable.query.value(price)(0, _datasource, _arg);
    }

    function provable_query(uint _timestamp, string memory _datasource, string memory _arg) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        return provable.query.value(price)(_timestamp, _datasource, _arg);
    }

    function provable_query(uint _timestamp, string memory _datasource, string memory _arg, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource,_gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        return provable.query_withGasLimit.value(price)(_timestamp, _datasource, _arg, _gasLimit);
    }

    function provable_query(string memory _datasource, string memory _arg, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
           return 0; 
        }
        return provable.query_withGasLimit.value(price)(0, _datasource, _arg, _gasLimit);
    }

    function provable_query(string memory _datasource, string memory _arg1, string memory _arg2) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        return provable.query2.value(price)(0, _datasource, _arg1, _arg2);
    }

    function provable_query(uint _timestamp, string memory _datasource, string memory _arg1, string memory _arg2) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        return provable.query2.value(price)(_timestamp, _datasource, _arg1, _arg2);
    }

    function provable_query(uint _timestamp, string memory _datasource, string memory _arg1, string memory _arg2, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        return provable.query2_withGasLimit.value(price)(_timestamp, _datasource, _arg1, _arg2, _gasLimit);
    }

    function provable_query(string memory _datasource, string memory _arg1, string memory _arg2, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        return provable.query2_withGasLimit.value(price)(0, _datasource, _arg1, _arg2, _gasLimit);
    }

    function provable_query(string memory _datasource, string[] memory _argN) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        bytes memory args = stra2cbor(_argN);
        return provable.queryN.value(price)(0, _datasource, args);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[] memory _argN) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        bytes memory args = stra2cbor(_argN);
        return provable.queryN.value(price)(_timestamp, _datasource, args);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[] memory _argN, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        bytes memory args = stra2cbor(_argN);
        return provable.queryN_withGasLimit.value(price)(_timestamp, _datasource, args, _gasLimit);
    }

    function provable_query(string memory _datasource, string[] memory _argN, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        bytes memory args = stra2cbor(_argN);
        return provable.queryN_withGasLimit.value(price)(0, _datasource, args, _gasLimit);
    }

    function provable_query(string memory _datasource, string[1] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](1);
        dynargs[0] = _args[0];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[1] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](1);
        dynargs[0] = _args[0];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[1] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](1);
        dynargs[0] = _args[0];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[1] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](1);
        dynargs[0] = _args[0];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[2] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[2] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[2] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[2] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[3] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[3] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[3] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[3] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[4] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[4] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[4] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[4] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[5] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[5] memory _args) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, string[5] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, string[5] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        string[] memory dynargs = new string[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[] memory _argN) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        bytes memory args = ba2cbor(_argN);
        return provable.queryN.value(price)(0, _datasource, args);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[] memory _argN) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource);
        if (price > 1 ether + tx.gasprice * 200000) {
            return 0; 
        }
        bytes memory args = ba2cbor(_argN);
        return provable.queryN.value(price)(_timestamp, _datasource, args);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[] memory _argN, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        bytes memory args = ba2cbor(_argN);
        return provable.queryN_withGasLimit.value(price)(_timestamp, _datasource, args, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[] memory _argN, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        uint price = provable.getPrice(_datasource, _gasLimit);
        if (price > 1 ether + tx.gasprice * _gasLimit) {
            return 0; 
        }
        bytes memory args = ba2cbor(_argN);
        return provable.queryN_withGasLimit.value(price)(0, _datasource, args, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[1] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](1);
        dynargs[0] = _args[0];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[1] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](1);
        dynargs[0] = _args[0];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[1] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](1);
        dynargs[0] = _args[0];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[1] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](1);
        dynargs[0] = _args[0];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[2] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[2] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[2] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[2] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](2);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[3] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[3] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[3] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[3] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](3);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[4] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[4] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[4] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[4] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](4);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[5] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[5] memory _args) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_timestamp, _datasource, dynargs);
    }

    function provable_query(uint _timestamp, string memory _datasource, bytes[5] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_timestamp, _datasource, dynargs, _gasLimit);
    }

    function provable_query(string memory _datasource, bytes[5] memory _args, uint _gasLimit) provableAPI internal returns (bytes32 _id) {
        bytes[] memory dynargs = new bytes[](5);
        dynargs[0] = _args[0];
        dynargs[1] = _args[1];
        dynargs[2] = _args[2];
        dynargs[3] = _args[3];
        dynargs[4] = _args[4];
        return provable_query(_datasource, dynargs, _gasLimit);
    }

    function provable_setProof(byte _proofP) provableAPI internal {
        return provable.setProofType(_proofP);
    }


    function provable_cbAddress() provableAPI internal returns (address _callbackAddress) {
        return provable.cbAddress();
    }

    function getCodeSize(address _addr) view internal returns (uint _size) {
        assembly {
            _size := extcodesize(_addr)
        }
    }

    function provable_setCustomGasPrice(uint _gasPrice) provableAPI internal {
        return provable.setCustomGasPrice(_gasPrice);
    }

    function provable_randomDS_getSessionPubKeyHash() provableAPI internal returns (bytes32 _sessionKeyHash) {
        return provable.randomDS_getSessionPubKeyHash();
    }

    function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    function strCompare(string memory _a, string memory _b) internal pure returns (int _returnCode) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) {
            minLength = b.length;
        }
        for (uint i = 0; i < minLength; i ++) {
            if (a[i] < b[i]) {
                return -1;
            } else if (a[i] > b[i]) {
                return 1;
            }
        }
        if (a.length < b.length) {
            return -1;
        } else if (a.length > b.length) {
            return 1;
        } else {
            return 0;
        }
    }

    function indexOf(string memory _haystack, string memory _needle) internal pure returns (int _returnCode) {
        bytes memory h = bytes(_haystack);
        bytes memory n = bytes(_needle);
        if (h.length < 1 || n.length < 1 || (n.length > h.length)) {
            return -1;
        } else if (h.length > (2 ** 128 - 1)) {
            return -1;
        } else {
            uint subindex = 0;
            for (uint i = 0; i < h.length; i++) {
                if (h[i] == n[0]) {
                    subindex = 1;
                    while(subindex < n.length && (i + subindex) < h.length && h[i + subindex] == n[subindex]) {
                        subindex++;
                    }
                    if (subindex == n.length) {
                        return int(i);
                    }
                }
            }
            return -1;
        }
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory _concatenatedString) {
        return strConcat(_a, _b, "", "", "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c) internal pure returns (string memory _concatenatedString) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d) internal pure returns (string memory _concatenatedString) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal pure returns (string memory _concatenatedString) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        uint i = 0;
        for (i = 0; i < _ba.length; i++) {
            babcde[k++] = _ba[i];
        }
        for (i = 0; i < _bb.length; i++) {
            babcde[k++] = _bb[i];
        }
        for (i = 0; i < _bc.length; i++) {
            babcde[k++] = _bc[i];
        }
        for (i = 0; i < _bd.length; i++) {
            babcde[k++] = _bd[i];
        }
        for (i = 0; i < _be.length; i++) {
            babcde[k++] = _be[i];
        }
        return string(babcde);
    }

    function safeParseInt(string memory _a) internal pure returns (uint _parsedInt) {
        return safeParseInt(_a, 0);
    }

    function safeParseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i = 0; i < bresult.length; i++) {
            if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
                if (decimals) {
                   if (_b == 0) break;
                    else _b--;
                }
                mint *= 10;
                mint += uint(uint8(bresult[i])) - 48;
            } else if (uint(uint8(bresult[i])) == 46) {
                require(!decimals, 'More than one decimal encountered in string!');
                decimals = true;
            } else {
                revert("Non-numeral character encountered in string!");
            }
        }
        if (_b > 0) {
            mint *= 10 ** _b;
        }
        return mint;
    }

    function parseInt(string memory _a) internal pure returns (uint _parsedInt) {
        return parseInt(_a, 0);
    }

    function parseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i = 0; i < bresult.length; i++) {
            if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
                if (decimals) {
                   if (_b == 0) {
                       break;
                   } else {
                       _b--;
                   }
                }
                mint *= 10;
                mint += uint(uint8(bresult[i])) - 48;
            } else if (uint(uint8(bresult[i])) == 46) {
                decimals = true;
            }
        }
        if (_b > 0) {
            mint *= 10 ** _b;
        }
        return mint;
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    function stra2cbor(string[] memory _arr) internal pure returns (bytes memory _cborEncoding) {
        safeMemoryCleaner();
        Buffer.buffer memory buf;
        Buffer.init(buf, 1024);
        buf.startArray();
        for (uint i = 0; i < _arr.length; i++) {
            buf.encodeString(_arr[i]);
        }
        buf.endSequence();
        return buf.buf;
    }

    function ba2cbor(bytes[] memory _arr) internal pure returns (bytes memory _cborEncoding) {
        safeMemoryCleaner();
        Buffer.buffer memory buf;
        Buffer.init(buf, 1024);
        buf.startArray();
        for (uint i = 0; i < _arr.length; i++) {
            buf.encodeBytes(_arr[i]);
        }
        buf.endSequence();
        return buf.buf;
    }

    function provable_newRandomDSQuery(uint _delay, uint _nbytes, uint _customGasLimit) internal returns (bytes32 _queryId) {
        require((_nbytes > 0) && (_nbytes <= 32));
        _delay *= 10; 
        bytes memory nbytes = new bytes(1);
        nbytes[0] = byte(uint8(_nbytes));
        bytes memory unonce = new bytes(32);
        bytes memory sessionKeyHash = new bytes(32);
        bytes32 sessionKeyHash_bytes32 = provable_randomDS_getSessionPubKeyHash();
        assembly {
            mstore(unonce, 0x20)
            
            mstore(add(unonce, 0x20), xor(blockhash(sub(number, 1)), xor(coinbase, timestamp)))
            mstore(sessionKeyHash, 0x20)
            mstore(add(sessionKeyHash, 0x20), sessionKeyHash_bytes32)
        }
        bytes memory delay = new bytes(32);
        assembly {
            mstore(add(delay, 0x20), _delay)
        }
        bytes memory delay_bytes8 = new bytes(8);
        copyBytes(delay, 24, 8, delay_bytes8, 0);
        bytes[4] memory args = [unonce, nbytes, sessionKeyHash, delay];
        bytes32 queryId = provable_query("random", args, _customGasLimit);
        bytes memory delay_bytes8_left = new bytes(8);
        assembly {
            let x := mload(add(delay_bytes8, 0x20))
            mstore8(add(delay_bytes8_left, 0x27), div(x, 0x100000000000000000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x26), div(x, 0x1000000000000000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x25), div(x, 0x10000000000000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x24), div(x, 0x100000000000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x23), div(x, 0x1000000000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x22), div(x, 0x10000000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x21), div(x, 0x100000000000000000000000000000000000000000000000000))
            mstore8(add(delay_bytes8_left, 0x20), div(x, 0x1000000000000000000000000000000000000000000000000))
        }
        provable_randomDS_setCommitment(queryId, keccak256(abi.encodePacked(delay_bytes8_left, args[1], sha256(args[0]), args[2])));
        return queryId;
    }

    function provable_randomDS_setCommitment(bytes32 _queryId, bytes32 _commitment) internal {
        provable_randomDS_args[_queryId] = _commitment;
    }

    function verifySig(bytes32 _tosignh, bytes memory _dersig, bytes memory _pubkey) internal returns (bool _sigVerified) {
        bool sigok;
        address signer;
        bytes32 sigr;
        bytes32 sigs;
        bytes memory sigr_ = new bytes(32);
        uint offset = 4 + (uint(uint8(_dersig[3])) - 0x20);
        sigr_ = copyBytes(_dersig, offset, 32, sigr_, 0);
        bytes memory sigs_ = new bytes(32);
        offset += 32 + 2;
        sigs_ = copyBytes(_dersig, offset + (uint(uint8(_dersig[offset - 1])) - 0x20), 32, sigs_, 0);
        assembly {
            sigr := mload(add(sigr_, 32))
            sigs := mload(add(sigs_, 32))
        }
        (sigok, signer) = safer_ecrecover(_tosignh, 27, sigr, sigs);
        if (address(uint160(uint256(keccak256(_pubkey)))) == signer) {
            return true;
        } else {
            (sigok, signer) = safer_ecrecover(_tosignh, 28, sigr, sigs);
            return (address(uint160(uint256(keccak256(_pubkey)))) == signer);
        }
    }

    function provable_randomDS_proofVerify__sessionKeyValidity(bytes memory _proof, uint _sig2offset) internal returns (bool _proofVerified) {
        bool sigok;
        
        bytes memory sig2 = new bytes(uint(uint8(_proof[_sig2offset + 1])) + 2);
        copyBytes(_proof, _sig2offset, sig2.length, sig2, 0);
        bytes memory appkey1_pubkey = new bytes(64);
        copyBytes(_proof, 3 + 1, 64, appkey1_pubkey, 0);
        bytes memory tosign2 = new bytes(1 + 65 + 32);
        tosign2[0] = byte(uint8(1)); 
        copyBytes(_proof, _sig2offset - 65, 65, tosign2, 1);
        bytes memory CODEHASH = hex"fd94fa71bc0ba10d39d464d0d8f465efeef0a2764e3887fcc9df41ded20f505c";
        copyBytes(CODEHASH, 0, 32, tosign2, 1 + 65);
        sigok = verifySig(sha256(tosign2), sig2, appkey1_pubkey);
        if (!sigok) {
            return false;
        }
        
        bytes memory LEDGERKEY = hex"7fb956469c5c9b89840d55b43537e66a98dd4811ea0a27224272c2e5622911e8537a2f8e86a46baec82864e98dd01e9ccc2f8bc5dfc9cbe5a91a290498dd96e4";
        bytes memory tosign3 = new bytes(1 + 65);
        tosign3[0] = 0xFE;
        copyBytes(_proof, 3, 65, tosign3, 1);
        bytes memory sig3 = new bytes(uint(uint8(_proof[3 + 65 + 1])) + 2);
        copyBytes(_proof, 3 + 65, sig3.length, sig3, 0);
        sigok = verifySig(sha256(tosign3), sig3, LEDGERKEY);
        return sigok;
    }

    function provable_randomDS_proofVerify__returnCode(bytes32 _queryId, string memory _result, bytes memory _proof) internal returns (uint8 _returnCode) {
        
        if ((_proof[0] != "L") || (_proof[1] != "P") || (uint8(_proof[2]) != uint8(1))) {
            return 1;
        }
        bool proofVerified = provable_randomDS_proofVerify__main(_proof, _queryId, bytes(_result), provable_getNetworkName());
        if (!proofVerified) {
            return 2;
        }
        return 0;
    }

    function matchBytes32Prefix(bytes32 _content, bytes memory _prefix, uint _nRandomBytes) internal pure returns (bool _matchesPrefix) {
        bool match_ = true;
        require(_prefix.length == _nRandomBytes);
        for (uint256 i = 0; i< _nRandomBytes; i++) {
            if (_content[i] != _prefix[i]) {
                match_ = false;
            }
        }
        return match_;
    }

    function provable_randomDS_proofVerify__main(bytes memory _proof, bytes32 _queryId, bytes memory _result, string memory _contextName) internal returns (bool _proofVerified) {
        
        uint ledgerProofLength = 3 + 65 + (uint(uint8(_proof[3 + 65 + 1])) + 2) + 32;
        bytes memory keyhash = new bytes(32);
        copyBytes(_proof, ledgerProofLength, 32, keyhash, 0);
        if (!(keccak256(keyhash) == keccak256(abi.encodePacked(sha256(abi.encodePacked(_contextName, _queryId)))))) {
            return false;
        }
        bytes memory sig1 = new bytes(uint(uint8(_proof[ledgerProofLength + (32 + 8 + 1 + 32) + 1])) + 2);
        copyBytes(_proof, ledgerProofLength + (32 + 8 + 1 + 32), sig1.length, sig1, 0);
        
        if (!matchBytes32Prefix(sha256(sig1), _result, uint(uint8(_proof[ledgerProofLength + 32 + 8])))) {
            return false;
        }
        
        
        bytes memory commitmentSlice1 = new bytes(8 + 1 + 32);
        copyBytes(_proof, ledgerProofLength + 32, 8 + 1 + 32, commitmentSlice1, 0);
        bytes memory sessionPubkey = new bytes(64);
        uint sig2offset = ledgerProofLength + 32 + (8 + 1 + 32) + sig1.length + 65;
        copyBytes(_proof, sig2offset - 64, 64, sessionPubkey, 0);
        bytes32 sessionPubkeyHash = sha256(sessionPubkey);
        if (provable_randomDS_args[_queryId] == keccak256(abi.encodePacked(commitmentSlice1, sessionPubkeyHash))) { 
            delete provable_randomDS_args[_queryId];
        } else return false;
        
        bytes memory tosign1 = new bytes(32 + 8 + 1 + 32);
        copyBytes(_proof, ledgerProofLength, 32 + 8 + 1 + 32, tosign1, 0);
        if (!verifySig(sha256(tosign1), sig1, sessionPubkey)) {
            return false;
        }
        
        if (!provable_randomDS_sessionKeysHashVerified[sessionPubkeyHash]) {
            provable_randomDS_sessionKeysHashVerified[sessionPubkeyHash] = provable_randomDS_proofVerify__sessionKeyValidity(_proof, sig2offset);
        }
        return provable_randomDS_sessionKeysHashVerified[sessionPubkeyHash];
    }
    
    function copyBytes(bytes memory _from, uint _fromOffset, uint _length, bytes memory _to, uint _toOffset) internal pure returns (bytes memory _copiedBytes) {
        uint minLength = _length + _toOffset;
        require(_to.length >= minLength); 
        uint i = 32 + _fromOffset; 
        uint j = 32 + _toOffset;
        while (i < (32 + _fromOffset + _length)) {
            assembly {
                let tmp := mload(add(_from, i))
                mstore(add(_to, j), tmp)
            }
            i += 32;
            j += 32;
        }
        return _to;
    }
    
    function safer_ecrecover(bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s) internal returns (bool _success, address _recoveredAddress) {
        
        bool ret;
        address addr;
        assembly {
            let size := mload(0x40)
            mstore(size, _hash)
            mstore(add(size, 32), _v)
            mstore(add(size, 64), _r)
            mstore(add(size, 96), _s)
            ret := call(3000, 1, 0, size, 128, size, 32) 
            addr := mload(size)
        }
        return (ret, addr);
    }
    
    function ecrecovery(bytes32 _hash, bytes memory _sig) internal returns (bool _success, address _recoveredAddress) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        if (_sig.length != 65) {
            return (false, address(0));
        }
        
        assembly {
            r := mload(add(_sig, 32))
            s := mload(add(_sig, 64))
            
            v := byte(0, mload(add(_sig, 96)))
            
        }
        
        if (v < 27) {
            v += 27;
        }
        if (v != 27 && v != 28) {
            return (false, address(0));
        }
        return safer_ecrecover(_hash, v, r, s);
    }

    function safeMemoryCleaner() internal pure {
        assembly {
            let fmem := mload(0x40)
            codecopy(fmem, codesize, sub(msize, fmem))
        }
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Context {
    constructor () internal { }
    

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; 
        return msg.data;
    }
}

contract Ownable is Context {
    address payable private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view returns (address payable) {
        return _owner;
    }
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address payable newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address payable newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 _totalSupply;
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}

contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract ReentrancyGuard {
    uint256 private _guardCounter;

    constructor () internal {
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { 
            
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

interface Compound {
    function mint ( uint256 mintAmount ) external returns ( uint256 );
    function redeem(uint256 redeemTokens) external returns (uint256);
    function exchangeRateStored() external view returns (uint);
}

interface Fulcrum {
    function mint(address receiver, uint256 amount) external payable returns (uint256 mintAmount);
    function burn(address receiver, uint256 burnAmount) external returns (uint256 loanAmountPaid);
    function assetBalanceOf(address _owner) external view returns (uint256 balance);
}

interface ILendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);
}

interface Aave {
    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external;
}

interface AToken {
    function redeem(uint256 amount) external;
}

interface IIEarnManager {
    function recommend(address _token) external view returns (
      string memory choice,
      uint256 capr,
      uint256 iapr,
      uint256 aapr,
      uint256 dapr
    );
}

contract Structs {
    struct Val {
        uint256 value;
    }

    enum ActionType {
        Deposit,   
        Withdraw  
    }

    enum AssetDenomination {
        Wei 
    }

    enum AssetReference {
        Delta 
    }

    struct AssetAmount {
        bool sign; 
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    struct Info {
        address owner;  
        uint256 number; 
    }

    struct Wei {
        bool sign; 
        uint256 value;
    }
}

contract DyDx is Structs {
    function getAccountWei(Info memory account, uint256 marketId) public view returns (Wei memory);
    function operate(Info[] memory, ActionArgs[] memory) public;
}

interface LendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);
    function getLendingPoolCore() external view returns (address);
}

contract yeldDAI is usingProvable, ERC20, ERC20Detailed, Ownable {
  address public yDAIAddress;
  uint256 public initialPrice = 10000;
  uint256 public fromYeldDAIToYeld = initialPrice * (10 ** 18); 
  uint256 public fromDAIToYeldDAIPrice = fromYeldDAIToYeld / initialPrice; 
  uint256 public yeldReward = 1;
  uint256 public yeldDAIDecimals = 18; 
  
  modifier onlyYDAI {
    require(msg.sender == yDAIAddress);
    _;
  }

  constructor() public ERC20Detailed("yeld DAI", "yeldDAI", 18) {}

  function setYDAI(address _yDAIAddress) public onlyOwner {
    yDAIAddress = _yDAIAddress;
  }
  
  function mint(address _to, uint256 _amount) public onlyYDAI {
    _mint(_to, _amount);
  }

  function burn(address _to, uint256 _amount) public onlyYDAI {
    _burn(_to, _amount);
  }
  
  
  
  function startOracle() public payable onlyOwner {
      require(msg.value >= 0.01 ether, 'The contract must hold at least 0.01 eth');
      provable_query(86400, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c.0"); 
  }

  
  
  
  
  
  
  
  function __callback(
  ) public {
    require(msg.sender == provable_cbAddress(), 'The callback function can only be executed by oraclize');

    
    yeldReward++;
    fromYeldDAIToYeld = initialPrice.mul(10 ** 18).div(yeldReward);
    fromDAIToYeldDAIPrice = fromYeldDAIToYeld.div(initialPrice);

    provable_query(86400, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c.0"); 
  }
  
  function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
    IERC20(_token).transfer(msg.sender, _amount);
  }

  function extractETHIfStuck() public onlyOwner {
    owner().transfer(address(this).balance);
  }
}

interface IYeldDAI {
  function yDAIAddress() external view returns(address);
  function initialPrice() external view returns(uint256);
  function fromYeldDAIToYeld() external view returns(uint256);
  function fromDAIToYeldDAIPrice() external view returns(uint256);
  function yeldReward() external view returns(uint256);
  function yeldDAIDecimals() external view returns(uint256);
  function mint(address _to, uint256 _amount) external;
  function burn(address _to, uint256 _amount) external;
  function balanceOf(address _of) external returns(uint256);
}

contract yDAI is ERC20, ERC20Detailed, ReentrancyGuard, Structs, Ownable {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  uint256 public pool;
  address public token;
  address public compound;
  address public fulcrum;
  address public aave;
  address public aavePool;
  address public aaveToken;
  address public dydx;
  uint256 public dToken;
  address public apr;
  address public chai;

  IYeldDAI public yeldDAIInstance;
  IERC20 public yeldToken;

  mapping(address => uint256) public deposited;

  enum Lender {
      NONE,
      DYDX,
      COMPOUND,
      AAVE,
      FULCRUM
  }

  Lender public provider = Lender.NONE;

  constructor (address _yeldToken, address _yeldDAIAddress) public payable ERC20Detailed("yearn DAI", "yDAI", 18) {
    token = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    apr = address(0xdD6d648C991f7d47454354f4Ef326b04025a48A8);
    dydx = address(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);
    aave = address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);
    aavePool = address(0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3);
    fulcrum = address(0x493C57C4763932315A328269E1ADaD09653B9081);
    aaveToken = address(0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d);
    compound = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    chai = address(0x06AF07097C9Eeb7fD685c692751D5C66dB49c215);
    dToken = 3;
    yeldDAIInstance = IYeldDAI(_yeldDAIAddress);
    yeldToken = IERC20(_yeldToken);
    approveToken();
  }

  mapping(bytes32 => uint256) public numberOfParticipants;

  function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
    IERC20(_token).transfer(msg.sender, _amount);
  }

  function extractETHIfStuck() public onlyOwner {
    owner().transfer(address(this).balance);
  }

  function deposit(uint256 _amount)
      external
      nonReentrant
  {
    require(_amount > 0, "deposit must be greater than 0");
    pool = calcPoolValueInToken();
    IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

    
    redeemYeld();
    uint256 yeldDAIToReceive = _amount.mul(yeldDAIInstance.fromDAIToYeldDAIPrice()).div(1 ** yeldDAIInstance.yeldDAIDecimals());
    deposited[msg.sender] = yeldDAIToReceive;
    yeldDAIInstance.mint(msg.sender, yeldDAIToReceive);
    

    
    uint256 shares = 0;
    if (pool == 0) {
      shares = _amount;
      pool = _amount;
    } else {
      shares = (_amount.mul(_totalSupply)).div(pool);
    }
    pool = calcPoolValueInToken();
    _mint(msg.sender, shares);
  }

  function redeemYeld() public {
    uint256 myYeldDAIBalance = yeldDAIInstance.balanceOf(msg.sender);
    if (myYeldDAIBalance == 0) return;

    uint256 yeldToRedeem = myYeldDAIBalance.div(yeldDAIInstance.fromYeldDAIToYeld()).div(1 ** yeldDAIInstance.yeldDAIDecimals());
    yeldDAIInstance.burn(msg.sender, deposited[msg.sender]);
    deposited[msg.sender] = 0;
    yeldToken.transfer(msg.sender, yeldToRedeem);
  }

  
  function withdraw(uint256 _shares)
      external
      nonReentrant
  {
      require(_shares > 0, "withdraw must be greater than 0");

      uint256 ibalance = balanceOf(msg.sender);
      require(_shares <= ibalance, "insufficient balance");

      
      pool = calcPoolValueInToken();
      
      uint256 r = (pool.mul(_shares)).div(_totalSupply);

      _balances[msg.sender] = _balances[msg.sender].sub(_shares, "redeem amount exceeds balance");
      _totalSupply = _totalSupply.sub(_shares);

      emit Transfer(msg.sender, address(0), _shares);

      
      uint256 b = IERC20(token).balanceOf(address(this));
      if (b < r) {
        _withdrawSome(r.sub(b));
      }

      IERC20(token).safeTransfer(msg.sender, r);
      pool = calcPoolValueInToken();

      redeemYeld();
  }

  function recommend() public view returns (Lender) {
    (,uint256 capr,uint256 iapr,uint256 aapr,uint256 dapr) = IIEarnManager(apr).recommend(token);
    uint256 max = 0;
    if (capr > max) {
      max = capr;
    }
    if (iapr > max) {
      max = iapr;
    }
    if (aapr > max) {
      max = aapr;
    }
    if (dapr > max) {
      max = dapr;
    }

    Lender newProvider = Lender.NONE;
    if (max == capr) {
      newProvider = Lender.COMPOUND;
    } else if (max == iapr) {
      newProvider = Lender.FULCRUM;
    } else if (max == aapr) {
      newProvider = Lender.AAVE;
    } else if (max == dapr) {
      newProvider = Lender.DYDX;
    }
    return newProvider;
  }

  function getAave() public view returns (address) {
    return LendingPoolAddressesProvider(aave).getLendingPool();
  }
  function getAaveCore() public view returns (address) {
    return LendingPoolAddressesProvider(aave).getLendingPoolCore();
  }

  function approveToken() public {
      IERC20(token).safeApprove(compound, uint(-1));
      IERC20(token).safeApprove(dydx, uint(-1));
      IERC20(token).safeApprove(getAaveCore(), uint(-1));
      IERC20(token).safeApprove(fulcrum, uint(-1));
  }

  function balance() public view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }
  function balanceDydxAvailable() public view returns (uint256) {
      return IERC20(token).balanceOf(dydx);
  }
  function balanceDydx() public view returns (uint256) {
      Wei memory bal = DyDx(dydx).getAccountWei(Info(address(this), 0), dToken);
      return bal.value;
  }
  function balanceCompound() public view returns (uint256) {
      return IERC20(compound).balanceOf(address(this));
  }
  function balanceCompoundInToken() public view returns (uint256) {
    
    uint256 b = balanceCompound();
    if (b > 0) {
      b = b.mul(Compound(compound).exchangeRateStored()).div(1e18);
    }
    return b;
  }
  function balanceFulcrumAvailable() public view returns (uint256) {
      return IERC20(chai).balanceOf(fulcrum);
  }
  function balanceFulcrumInToken() public view returns (uint256) {
    uint256 b = balanceFulcrum();
    if (b > 0) {
      b = Fulcrum(fulcrum).assetBalanceOf(address(this));
    }
    return b;
  }
  function balanceFulcrum() public view returns (uint256) {
    return IERC20(fulcrum).balanceOf(address(this));
  }
  function balanceAaveAvailable() public view returns (uint256) {
      return IERC20(token).balanceOf(aavePool);
  }
  function balanceAave() public view returns (uint256) {
    return IERC20(aaveToken).balanceOf(address(this));
  }

  function rebalance() public {
    Lender newProvider = recommend();

    if (newProvider != provider) {
      _withdrawAll();
    }

    if (balance() > 0) {
      if (newProvider == Lender.DYDX) {
        _supplyDydx(balance());
      } else if (newProvider == Lender.FULCRUM) {
        _supplyFulcrum(balance());
      } else if (newProvider == Lender.COMPOUND) {
        _supplyCompound(balance());
      } else if (newProvider == Lender.AAVE) {
        _supplyAave(balance());
      }
    }

    provider = newProvider;
  }

  function _withdrawAll() internal {
    uint256 amount = balanceCompound();
    if (amount > 0) {
      _withdrawSomeCompound(balanceCompoundInToken().sub(1));
    }
    amount = balanceDydx();
    if (amount > 0) {
      if (amount > balanceDydxAvailable()) {
        amount = balanceDydxAvailable();
      }
      _withdrawDydx(amount);
    }
    amount = balanceFulcrum();
    if (amount > 0) {
      if (amount > balanceFulcrumAvailable().sub(1)) {
        amount = balanceFulcrumAvailable().sub(1);
      }
      _withdrawSomeFulcrum(amount);
    }
    amount = balanceAave();
    if (amount > 0) {
      if (amount > balanceAaveAvailable()) {
        amount = balanceAaveAvailable();
      }
      _withdrawAave(amount);
    }
  }

  function _withdrawSomeCompound(uint256 _amount) internal {
    uint256 b = balanceCompound();
    uint256 bT = balanceCompoundInToken();
    require(bT >= _amount, "insufficient funds");
    
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawCompound(amount);
  }

  function _withdrawSomeFulcrum(uint256 _amount) internal {
    uint256 b = balanceFulcrum();
    uint256 bT = balanceFulcrumInToken();
    require(bT >= _amount, "insufficient funds");
    
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFulcrum(amount);
  }


  function _withdrawSome(uint256 _amount) internal returns (bool) {
    uint256 origAmount = _amount;

    uint256 amount = balanceCompound();
    if (amount > 0) {
      if (_amount > balanceCompoundInToken().sub(1)) {
        _withdrawSomeCompound(balanceCompoundInToken().sub(1));
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawSomeCompound(_amount);
        return true;
      }
    }

    amount = balanceDydx();
    if (amount > 0) {
      if (_amount > balanceDydxAvailable()) {
        _withdrawDydx(balanceDydxAvailable());
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawDydx(_amount);
        return true;
      }
    }

    amount = balanceFulcrum();
    if (amount > 0) {
      if (_amount > balanceFulcrumAvailable().sub(1)) {
        amount = balanceFulcrumAvailable().sub(1);
        _withdrawSomeFulcrum(balanceFulcrumAvailable().sub(1));
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawSomeFulcrum(amount);
        return true;
      }
    }

    amount = balanceAave();
    if (amount > 0) {
      if (_amount > balanceAaveAvailable()) {
        _withdrawAave(balanceAaveAvailable());
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawAave(_amount);
        return true;
      }
    }

    return true;
  }

  function _supplyDydx(uint256 amount) internal {
      Info[] memory infos = new Info[](1);
      infos[0] = Info(address(this), 0);

      AssetAmount memory amt = AssetAmount(true, AssetDenomination.Wei, AssetReference.Delta, amount);
      ActionArgs memory act;
      act.actionType = ActionType.Deposit;
      act.accountId = 0;
      act.amount = amt;
      act.primaryMarketId = dToken;
      act.otherAddress = address(this);

      ActionArgs[] memory args = new ActionArgs[](1);
      args[0] = act;

      DyDx(dydx).operate(infos, args);
  }

  function _supplyAave(uint amount) internal {
      Aave(getAave()).deposit(token, amount, 0);
  }
  function _supplyFulcrum(uint amount) internal {
      require(Fulcrum(fulcrum).mint(address(this), amount) > 0, "FULCRUM: supply failed");
  }
  function _supplyCompound(uint amount) internal {
      require(Compound(compound).mint(amount) == 0, "COMPOUND: supply failed");
  }
  function _withdrawAave(uint amount) internal {
      AToken(aaveToken).redeem(amount);
  }
  function _withdrawFulcrum(uint amount) internal {
      require(Fulcrum(fulcrum).burn(address(this), amount) > 0, "FULCRUM: withdraw failed");
  }
  function _withdrawCompound(uint amount) internal {
      require(Compound(compound).redeem(amount) == 0, "COMPOUND: withdraw failed");
  }

  function _withdrawDydx(uint256 amount) internal {
      Info[] memory infos = new Info[](1);
      infos[0] = Info(address(this), 0);

      AssetAmount memory amt = AssetAmount(false, AssetDenomination.Wei, AssetReference.Delta, amount);
      ActionArgs memory act;
      act.actionType = ActionType.Withdraw;
      act.accountId = 0;
      act.amount = amt;
      act.primaryMarketId = dToken;
      act.otherAddress = address(this);

      ActionArgs[] memory args = new ActionArgs[](1);
      args[0] = act;

      DyDx(dydx).operate(infos, args);
  }

  function calcPoolValueInToken() public view returns (uint) {
    return balanceCompoundInToken()
      .add(balanceFulcrumInToken())
      .add(balanceDydx())
      .add(balanceAave())
      .add(balance());
  }

  function getPricePerFullShare() public view returns (uint) {
    uint _pool = calcPoolValueInToken();
    return _pool.mul(1e18).div(_totalSupply);
  }
}