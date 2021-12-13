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

    // Bytes to string

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
    
    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly { // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }
        
    function StringToUint(string memory numString) public pure returns(uint) {
        uint val=0;
        bytes memory stringBytes = bytes(numString);
        for (uint  i =  0; i<stringBytes.length; i++) {
            uint exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
           uint jval = uval - uint(0x30);
   
           val +=  (uint(jval) * (10**(exp-1))); 
        }
      return val;
    }

    //define state variables stored on the block chain
    uint256 public currentPrice;
    address public owner;
    address public Oracle;
    bytes32 public jobId;
    uint256 public fee; 
    
    mapping(bytes32 => string[]) RequestToPrice;
    
    //constructor is run at the time of contract creating
    constructor() public {
        setPublicChainlinkToken();
        owner = msg.sender;
        Oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    // Create a modifier onlyOwner that checks whether the request has been made by the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    // The function below is meant to request and store the information from Italo's website
    function requestInfo(string memory _stationDeparture, string memory _stationArrival,
                         uint _datetimeDeparture) public returns (bytes32 requestId) {

        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        //set the url to perform the GET request so that the request is built adaptively
        string memory query = string(abi.encodePacked("https://9e37-93-66-104-18.ngrok.io/buy_ticket/?departure_station=", 
                                                _stationDeparture, "&arrival_station=", _stationArrival, 
                                                "&datetime_departure=", _datetimeDeparture));
        request.add("get", query);

        //set the path to find the requred data in the api response
        request.add("path", "response");

        //multiply the results by 100 to remove decimals
        request.addInt("times", 100);

        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }
    
    function fulfill(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {
        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string = bytes32ToString(_response);
        // Split the string response_string based on underscores, so that you can index the response inside 
        // the RequestToPrice mapping
        string[] memory response_list = split(response_string, "_");
        // Store, under the requestId key, the response string you get from the call
        RequestToPrice[_requestId] = response_list;
    }


    struct Ticket {
        address payable owner;
        uint train_number;
        uint price;
        uint datetime_departure;
        uint datetime_arrival_predicted;
        string station_departure;
        string station_arrival;
    }

    mapping(uint => mapping(uint => Ticket[])) TicketsByTrainNumberByDatetime;

    // Function buyTicket enters into action when a call has been made to the webscraper. 
    // Remember there is a placeholder for a certain requestId inside the RequestToPrice mapping and here is where
    // we are going to use it
    function buyTicket(bytes32 _requestId) public payable {

        // Instantiate the actual price from string to uint to allow comparison with the msg.value
        uint _actualPrice = StringToUint(RequestToPrice[_requestId][4]);

        // We should potentially add a way in which we could transform the price from euro to ETH (or whichever value)

        // Here i put index 4 but we need to change it as soon as we integrate the function
        require(msg.value >= _actualPrice);

        // Instantiate all of the variables by using the RequestToPrice array
        address payable _owner = msg.sender;
        uint _trainNumber = 32;
        uint _price = 40;
        uint _datetimeDeparture = 40;
        uint _datetimeArrivalPredicted = 60;
        string memory _stationDeparture = "Milano Centrale";
        string memory _stationArrival = "Roma Termini";

        // Push the Ticket inside the Ticket array, given train number and given the datetime
        TicketsByTrainNumberByDatetime[_trainNumber][_datetimeArrivalPredicted].push(Ticket(_owner, _trainNumber, _price, _datetimeDeparture, _datetimeArrivalPredicted, _stationDeparture,  _stationArrival));
    }

}