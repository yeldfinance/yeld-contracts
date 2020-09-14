pragma solidity 0.5.17;

import "@chainlink/contracts/src/v0.5/ChainlinkClient.sol";

contract Oracle is ChainlinkClient {
    uint256 public oraclePayment = 0.1 * LINK;
    address payable owner = msg.sender;
    uint256 public count = 1;
    bytes32 public jobId = '6b81ed67816648ec95ab9397f7a0df7d';
    address public oracle = 0xF5a3d443FccD7eE567000E43B23b0e98d96445CE;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        setPublicChainlinkToken();
    }

    function startOracle() public onlyOwner {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.__callback.selector);
        request.addUint("until", now + 2 seconds);
        sendChainlinkRequestTo(oracle, request, oraclePayment);
    }

    function __callback(bytes32 _requestId) public recordChainlinkFulfillment(_requestId) {
        count++;
        
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.__callback.selector);
        request.addUint("until", now + 1 minutes);
        sendChainlinkRequestTo(oracle, request, oraclePayment);
    }
}