pragma solidity ^0.5.0;

import "https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.5/ChainlinkClient.sol";
import "LibraryUtils.sol";

//contracts are like classes
//this Chainlink example inherits from ChainlinkClient

contract ChainlinkExample is ChainlinkClient {
    
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
                         string memory _trainNumber, string memory _datetimeDeparture,
                         string memory _datetimeArrivalPredicted, string memory _price) public returns (bytes32 requestId) {

        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        //set the url to perform the GET request so that the request is built adaptively
        string memory query = string(abi.encodePacked("https://fd5e-2001-b07-a3c-400a-b561-bc22-61b9-a720.ngrok.io", 
                                                      "/fake_ticket_search/?", 
                                                      "departure_station=", _stationDeparture, 
                                                      "&arrival_station=", _stationArrival, 
                                                      "&train_number=", _trainNumber,
                                                      "&time_of_departure=", _datetimeDeparture, 
                                                      "&time_of_arrival=", _datetimeArrivalPredicted, 
                                                      "&price=", _price));
        request.add("get", query);

        //set the path to find the requred data in the api response
        request.add("path", "response");

        // Keep track of the requests with the counter
        counter += 1;
        string memory counter_str = Converter.UintToString(counter);
        emit TicketInfo(string(abi.encodePacked("Your ticket has been successfully stored inside our database! To buy it, please insert the following request ID inside the GetKeccak function:", counter_str)));

        //send the request
        return sendChainlinkRequestTo(Oracle, request, fee);
    }
    
    function fulfill(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {

        string memory counter_str = Converter.UintToString(counter);
        bytes32 counter_key = keccak256(abi.encode(counter_str));

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string_info = Converter.bytes32ToString(_response);

        // Split the string response_string based on underscores, so that you can index the response inside 
        // the RequestToPrice mapping
        string[] memory response_list_info = Converter.split(response_string_info, "_");
        
        // Store, under the requestId key, the response string you get from the call
        RequestToPrice[counter_key] = response_list_info;
    }

    // Function used to turn strings into keccak bytes32
    function TurnCounterIntoKeccak(string memory _counter) public pure returns (bytes32) {
        bytes32 kecca_hashed_counter = keccak256(abi.encode(_counter));
        return (kecca_hashed_counter);
    }

    // Function buyTicket enters into action when a call has been made to the webscraper. 
    // Remember there is a placeholder for a certain requestId inside the RequestToPrice mapping and here is where
    // we are going to use it
    function buyTicket(bytes32 _requestId) public payable {

        // Instantiate the actual price from string to uint to allow comparison with the msg.value
        uint actual_price = Converter.StringToUint(RequestToPrice[_requestId][4]);

        // We should potentially add a way in which we could transform the price from euro to ETH (or whichever value)

        // Here i put index 4 but we need to change it as soon as we integrate the function
        require(msg.value >= actual_price, "You have paid too little! Try again.");

        // Instantiate all of the variables by using the RequestToPrice array
        address payable _owner = msg.sender;

        string memory _stationDeparture = RequestToPrice[_requestId][0];
        uint _datetimeArrivalPredicted = Converter.StringToUint(RequestToPrice[_requestId][1]);
        string memory _stationArrival = RequestToPrice[_requestId][2];
        uint _trainNumber = Converter.StringToUint(RequestToPrice[_requestId][3]);
        uint _price = Converter.StringToUint(RequestToPrice[_requestId][4]);
        
        // Emit an event telling the user in which case he's supposed to ask for a refund 
        emit TicketInfo(string(abi.encodePacked("You have successfully bought your ticket from ", _stationDeparture, " to ", _stationArrival, ". The train ", _trainNumber ," is scheduled to arrive at ", _datetimeArrivalPredicted, ". Make sure to ask for a refund in case of delay! Thanks for choosing our service")));

        // Push the Ticket inside the Ticket array, given train number and given the datetime
        TicketsByTrainNumberByDatetime[_trainNumber][_datetimeArrivalPredicted].push(Ticket(_owner, _trainNumber, _price, _datetimeArrivalPredicted, _stationDeparture,  _stationArrival));

        // Remove the RequestId from the RequestToPrice mapping to avoid storing useless stuff
        delete RequestToPrice[_requestId];
    }


    // The function below is meant to request and store the information from Italo's website
    function checkDelay(string memory _trainNumber, string memory _expectedArr,
                        string memory _delay, string memory _thr) public returns (bytes32 requestId) {

        //create a variable and store it temporarily in memory
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill_delay.selector);

        //set the url to perform the GET request so that the request is built adaptively
        string memory query = string(abi.encodePacked("https://fd5e-2001-b07-a3c-400a-b561-bc22-61b9-a720.ngrok.io", 
                                                      "/fake_delay/?", 
                                                      "train_number=", _trainNumber,
                                                      "&expected_arr=", _expectedArr,
                                                      "&delay=", _delay,
                                                      "&thr=", _thr));
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
        response_string = Converter.bytes32ToString(_response);

        // Store the response_string inside a variable, after having transformed the bytes32 response into a string
        string memory response_string_delay = Converter.bytes32ToString(_response);

        // Split the string response_string based on underscores, so that you can index the response inside 
        // the RequestToPrice mapping
        string[] memory response_list_delay = Converter.split(response_string_delay, "_");

        string memory boolean = response_list_delay[0];
        uint _trainNumber_Delay = Converter.StringToUint(response_list_delay[1]);
        uint _datetimeArrivalPredicted_Delay = Converter.StringToUint(response_list_delay[2]);
        uint _minutesOfDelay = Converter.StringToUint(response_list_delay[3]);
        uint length_ticketlist = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay].length;

        // Check by how many minutes the train has delayed
        if (keccak256(abi.encodePacked(boolean))==keccak256(abi.encodePacked("True"))) {
            if (_minutesOfDelay > 10) {
                for (uint i=0; i < length_ticketlist; i++){
                    Ticket memory this_ticket = TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay][i];
                    address payable owner_to_be_repaid = this_ticket.owner;
                    uint amount_to_be_repaid = ((this_ticket.price * 10) / 100) - ((this_ticket.price * 10) % 100);
                    owner_to_be_repaid.transfer(amount_to_be_repaid);
                }
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
        }

        delete TicketsByTrainNumberByDatetime[_trainNumber_Delay][_datetimeArrivalPredicted_Delay];
    }

}
