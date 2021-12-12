pragma solidity ^0.5.0;

import "https://github.com/willitscale/solidity-util/blob/master/lib/Strings.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.5/ChainlinkClient.sol";


//contracts are like classes
//this Chainlink example inherits from ChainlinkClient

contract ChainlinkExample is ChainlinkClient {

    string[] public stringaSplitted;

    function _indexOf(string memory _base, string memory _value, uint _offset)
        internal
        pure
        returns (int) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length == 1);

        for (uint i = _offset; i < _baseBytes.length; i++) {
            if (_baseBytes[i] == _valueBytes[0]) {
                return int(i);
            }
        }

        return -1;
    }

    function indexOf(string memory _base, string memory _value)
        internal
        pure
        returns (int) {
        return _indexOf(_base, _value, 0);
    }
    
    function split(string memory _base, string memory _value)
        internal
        pure
        returns (string[] memory splitArr) {
        bytes memory _baseBytes = bytes(_base);

        uint _offset = 0;
        uint _splitsCount = 1;
        while (_offset < _baseBytes.length - 1) {
            int _limit = _indexOf(_base, _value, _offset);
            if (_limit == -1)
                break;
            else {
                _splitsCount++;
                _offset = uint(_limit) + 1;
            }
        }

        splitArr = new string[](_splitsCount);

        _offset = 0;
        _splitsCount = 0;
        while (_offset < _baseBytes.length - 1) {

            int _limit = _indexOf(_base, _value, _offset);
            if (_limit == - 1) {
                _limit = int(_baseBytes.length);
            }

            string memory _tmp = new string(uint(_limit) - _offset);
            bytes memory _tmpBytes = bytes(_tmp);

            uint j = 0;
            for (uint i = _offset; i < uint(_limit); i++) {
                _tmpBytes[j++] = _baseBytes[i];
            }
            _offset = uint(_limit) + 1;
            splitArr[_splitsCount++] = string(_tmpBytes);
        }
        return splitArr;
    }

    function MySplit(string memory _base, string memory _value) public {
        stringaSplitted = split(_base, _value);
    }

    //define state variables stored on the block chain
    uint256 public currentPrice;
    address public owner;
    address public Oracle;
    bytes32 public jobId;
    uint256 public fee; 
    
    
    //constructor is run at the time of contract creating
    constructor() public {
        setPublicChainlinkToken();
        owner = msg.sender;
        Oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }
    
    //function below creates a Chainlink API request to get a price
    //only the owner of the contract can call this function
    function requestPrice() public onlyOwner returns (bytes32 requestId)
    {
        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        //set the url to perform the GET request
        request.add("get", "https://9e37-93-66-104-18.ngrok.io/buy_ticket/?owner=0x6a522cf77C1B37540bBAB6995783a0B11d7F3d36&ticket_id=7329515239218365070");
        //set the path to find the requred data in the api response
        request.add("path", "price");
        //multiply the results by 100 to remove decimals
        request.addInt("times", 100);
        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }
    
    function fulfill(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId) 
    {
        currentPrice = _price;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    }