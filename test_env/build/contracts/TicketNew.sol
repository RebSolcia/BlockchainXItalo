pragma solidity ^0.5.0;

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.5/ChainlinkClient.sol";

//contracts are like classes
//this Chainlink example inherits from ChainlinkClient

contract ChainlinkExample is ChainlinkClient {
    
    // FUNCTIONS THAT ARE NEEDED TO TURN A STRING INTO A LIST OF STRINGS
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

    // FUNCTIONS THAT ARE NEEDED TO TURN A BYTES32 INTO A STRING AND VICE-VERSA
    function bytes32ToString(bytes32 _bytes32) private pure returns (string memory) {
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

    // FUNCTIONS THAT ARE NEEDED TO TURN A STRING INTO A UINT        
    function StringToUint(string memory numString) private pure returns(uint) {
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

    function UintToString(uint _i) internal pure returns (string memory _uintAsString) {
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

    // TRIAL CODE FOR SPLITTING TO SEE WHETHER IT WORKS
    string[] public stringaSplitted;

    function MySplit(string memory _base, string memory _value) public {
        stringaSplitted = split(_base, _value);
    }
    
    //constructor is run at the time of contract creating
    constructor() public {
        setPublicChainlinkToken();
        owner = msg.sender;
        Oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "7401f318127148a894c00c292e486ffd";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    // Create a modifier onlyOwner that checks whether the request has been made by the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    //define state variables stored on the block chain
    uint256 public currentPrice;
    address public owner;
    address public Oracle;
    bytes32 public jobId;
    uint256 public fee; 
    bytes32 public bytesdirisposta;
    string public response_string;
    uint public counter = 0;

    struct Ticket {
        address payable owner;
        uint train_number;
        uint price;
        uint datetime_departure;
        uint datetime_arrival_predicted;
        string station_departure;
        string station_arrival;
    }

    // This mapping is made public so that for now we can debug and see whether tickets are added in the right way
    mapping(bytes32 => string[]) public RequestToPrice;
    // This mapping stores tickets by train number and by predicted arrival time
    mapping(uint => mapping(uint => Ticket[])) public TicketsByTrainNumberByDatetime;

    event TicketInfo (string successMessage);
    
    // The function below is meant to request and store the information from Italo's website
    function requestInfo(string memory _stationDeparture, string memory _stationArrival,
                         string memory _datetimeDeparture) public returns (bytes32 requestId) {

        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        //set the url to perform the GET request so that the request is built adaptively
        string memory query = string(abi.encodePacked("https://fd5e-2001-b07-a3c-400a-b561-bc22-61b9-a720.ngrok.io", 
                                                      "/request_info_mock/?", 
                                                      "departure_station=", _stationDeparture, 
                                                      "&arrival_station=", _stationArrival, 
                                                      "&departure_hour=", _datetimeDeparture));
        request.add("get", query);

        //set the path to find the requred data in the api response
        request.add("path", "response");

        // Keep track of the requests with the counter
        counter += 1;
        string memory counter_str = UintToString(counter);
        emit TicketInfo(string(abi.encodePacked("Your ticket has been successfully stored inside our database! To buy it, please insert the following request ID inside the GetKeccak function:", counter_str)));

        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }

    function TurnCounterIntoKeccak(string memory _counter) public pure returns (bytes32) {
        bytes32 kecca_hashed_counter = keccak256(abi.encode(_counter));
        return (kecca_hashed_counter);
    }
    
    function fulfill(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {

        string memory counter_str = UintToString(counter);
        bytes32 counter_key = keccak256(abi.encode(counter_str));

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string_info = bytes32ToString(_response);

        // Split the string response_string based on underscores, so that you can index the response inside 
        // the RequestToPrice mapping
        string[] memory response_list_info = split(response_string_info, "_");
        
        // Store, under the requestId key, the response string you get from the call
        RequestToPrice[counter_key] = response_list_info;
    }

    // The function below is meant to request and store the information from Italo's website
    function checkDelay(string memory _trainNumber) public returns (bytes32 requestId) {

        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill_delay.selector);

        //set the url to perform the GET request so that the request is built adaptively
        string memory query = string(abi.encodePacked("https://fd5e-2001-b07-a3c-400a-b561-bc22-61b9-a720.ngrok.io", 
                                                      "/check_delay/?", 
                                                      "train_number=", _trainNumber));
        request.add("get", query);

        //set the path to find the requred data in the api response
        request.add("path", "response");

        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }
    
    function fulfill_delay(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {
        // Parse the response as "trainnumber_datetimearrivalpredicted_minutesofdelay"
        bytesdirisposta = _response;

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string_delay = bytes32ToString(_response);

        // Split the string response_string based on underscores, so that you can index the response inside 
        // the RequestToPrice mapping
        string[] memory response_list_delay = split(response_string_delay, "_");

        uint _trainNumber_Delay = StringToUint(response_list_delay[0]);
        uint _datetimeArrivalPredicted_Delay = StringToUint(response_list_delay[1]);
        uint _minutesOfDelay = StringToUint(response_list_delay[2]);
        uint length_ticketlist = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay].length;

        // Check by how many minutes the train has delayed
        if (_minutesOfDelay > 10) {
            for (uint i=0; i < length_ticketlist; i++){
                Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                address payable owner_to_be_repaid = this_ticket.owner;
                uint amount_to_be_repaid = ((this_ticket.price * 10) / 100) - ((this_ticket.price * 10) % 100);
                owner_to_be_repaid.transfer(amount_to_be_repaid);
            }

            emit TicketInfo("The tickets ")

        } else if (_minutesOfDelay > 60) {
            for (uint i=0; i < length_ticketlist; i++){
                Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                address payable owner_to_be_repaid = this_ticket.owner;
                uint amount_to_be_repaid = ((this_ticket.price * 60) / 100) - ((this_ticket.price * 60) % 100);
                owner_to_be_repaid.transfer(amount_to_be_repaid);
            }
        } else if (_minutesOfDelay > 90) {
            for (uint i=0; i < length_ticketlist; i++){
                Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                address payable owner_to_be_repaid = this_ticket.owner;
                uint amount_to_be_repaid = ((this_ticket.price * 90) / 100) - ((this_ticket.price * 90) % 100);
                owner_to_be_repaid.transfer(amount_to_be_repaid);
            }
        }

        delete TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay];

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        response_string = bytes32ToString(_response);
    }

    // Function buyTicket enters into action when a call has been made to the webscraper. 
    // Remember there is a placeholder for a certain requestId inside the RequestToPrice mapping and here is where
    // we are going to use it
    function buyTicket(bytes32 _requestId) public payable {

        // Instantiate the actual price from string to uint to allow comparison with the msg.value
        uint actual_price = StringToUint(RequestToPrice[_requestId][4]);

        // We should potentially add a way in which we could transform the price from euro to ETH (or whichever value)

        // Here i put index 4 but we need to change it as soon as we integrate the function
        require(msg.value >= actual_price, "You have paid too little! Try again.");

        // Instantiate all of the variables by using the RequestToPrice array
        address payable _owner = msg.sender;

        string memory _stationDeparture = RequestToPrice[_requestId][0];
        uint _datetimeArrivalPredicted = StringToUint(RequestToPrice[_requestId][1]);
        string memory _stationArrival = RequestToPrice[_requestId][2];
        uint _trainNumber = StringToUint(RequestToPrice[_requestId][3]);
        uint _price = StringToUint(RequestToPrice[_requestId][4]);

        uint _datetimeDeparture = 14;
        
        // Emit an event telling the user in which case he's supposed to ask for a refund 
        emit TicketInfo(string(abi.encodePacked("You have successfully bought your ticket from ", _stationDeparture, " to ", _stationArrival, ". The train ", _trainNumber ," is scheduled to arrive at ", _datetimeArrivalPredicted, ". Make sure to ask for a refund in case of delay! Thanks for choosing our service")));

        // Push the Ticket inside the Ticket array, given train number and given the datetime
        TicketsByTrainNumberByDatetime[_trainNumber][_datetimeArrivalPredicted].push(Ticket(_owner, _trainNumber, _price, _datetimeDeparture, _datetimeArrivalPredicted, _stationDeparture,  _stationArrival));

        // Remove the RequestId from the RequestToPrice mapping to avoid storing useless stuff
        delete RequestToPrice[_requestId];
    }

}
