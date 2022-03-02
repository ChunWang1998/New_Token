pragma solidity ^0.4.24;
import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "./SeedRound.sol";

/*
the main contract to control the dirrent time ICO, and initial token is 300 milion.
300 million token store in balance[sender]
transfer 20 million to SeedRound  
*/
contract RealBlockToken is StandardToken {
    string public name;
    string public symbol;
    uint256 public decimals = 18;
    uint256 public INITIAL_SUPPLY = 300000000 * (10**decimals); // check?
    address public admin;
    SeedRound public SeedRound_in_main;
    address public newContract;
    event Log(string message);

    constructor() public {
        //"function" in reference
        name = "RealBlockToken";
        symbol = "RBT";
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        admin = msg.sender;
        newContract = new SeedRound();
        SeedRound_in_main = SeedRound(newContract);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "you are not admin");
        _;
    }

    function sentRBT_to_SeedRound() public onlyAdmin {
        uint256 sent_value = 10; //for test
        SeedRound_in_main.sentRBT_FromAdmin(sent_value);
        balances[msg.sender] -= sent_value;
    }

    function Check_RBT_in_SeedRound() public view onlyAdmin returns (uint256) {
        //return balances[msg.sender];
        return SeedRound_in_main.totalRBT();
    }
    // function sayHello() public returns (string) {//for truffle test
    //   return ("Hello World");
    // }
}
