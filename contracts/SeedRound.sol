pragma solidity >=0.4.21 <=0.8.12;
 import "zeppelin-solidity/contracts/math/SafeMath.sol";
 import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
/*
    from main.sol get 2000,0000 RBT
    enable user to transfer eth(basic) to this contract, and sent user corresponding RBT token.
    after ICO time pass, this contract will self destruct and turn eth back to admin 
    ETH-USD can only get from ropsten/rinkeby/mainnet
    */

//for prices
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract SeedRound is StandardToken {
    uint256 public saleStart;
    uint256 public staking_time;
    uint256 public saleEnd;
    uint256 public constant SECONDS_PER_LOCK_PERIOD = 30 days;
    uint256 public constant VESTED_PERIOD = 12;
    uint256 public vested_record; //for vested
    address public admin; //same as main.sol admin
    uint256 public vested_period_cnt;

    uint256 public totalRBT;
    uint256 public initial_totalRBT; //20 million
    uint256 public User_totalRBT;
    uint256 constant SEEDROUND_STAKING_PERCENTAGE = 30; //assume feedback is 30% ,but solidity doesn't support float

    address[] public addressIndices; //when staking, we should know who has invested.

    //to show that how many percent of RBT were bought
    uint256 private percentage;

    mapping(address => uint256) public RBT_balances; //for RBT, lock for one year(locked)
    bool public RBT_balances_available;
    mapping(address => uint256) public RBT_balances_per_vested; //for vested

    mapping(address => uint256) public RBT_staking; //can use after SeedRound end(locked)
    mapping(address => uint256) public per_RBT_staking; //divide RBT_staking into 365

    mapping(address => uint256) public Available_RBT; //the RBT which can withdraw to metamask(unlocked)

    mapping(address => uint256) public balances; //for eth

    mapping(address => bool) public Not_First_buy; // init are all false

    AggregatorV3Interface ETHFeed;
    AggregatorV3Interface BTCFeed;

    using SafeMath for uint256;

    constructor() public {
        admin = msg.sender;
        balances[msg.sender] = 0;
        User_totalRBT = 0;
        saleStart = now;
        staking_time = now;
        ETHFeed = AggregatorV3Interface(
            0x9326BFA02ADD2366b30bacB125260Af641031331
        ); //kovan
        //ETHFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);mainNet
        BTCFeed = AggregatorV3Interface(
            0x6135b13325bfC4B00278B4abC5e20bbce2D6580e
        ); //kovan
        //BTCFeed = AggregatorV3Interface(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);//mainNet
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "you are not admin");
        _;
    }

    //     function getLinkPriceETH() public view returns (uint) {
    //         (
    //             uint80 roundID,
    //             int price,
    //             uint startedAt,
    //             uint timeStamp,
    //             uint80 answeredInRound
    //         ) = ETHFeed.latestRoundData();
    //         // If the round is not complete yet, timestamp is 0
    //         require(timeStamp > 0, "Round not complete");
    //         return uint(price);
    //     }

    //     function getLinkPriceBTC() public view returns (uint) {
    //         (
    //             uint80 roundID,
    //             int price,
    //             uint startedAt,
    //             uint timeStamp,
    //             uint80 answeredInRound
    //         ) = BTCFeed.latestRoundData();
    //         // If the round is not complete yet, timestamp is 0
    //         require(timeStamp > 0, "Round not complete");
    //         return uint(price);
    //     }

    function sentRBT_FromAdmin(uint256 RBTtoken) public returns (uint256) {
        totalRBT = totalRBT.add(RBTtoken);
        initial_totalRBT = RBTtoken;
        return totalRBT;
    }

    //use the Price to determine how many RBT they can buy(EX: I want to buy 100RBT,equal to 10 USD, equal to 0.0176eth,
    //so the msg.value should be 0.0176)

    function Invest() public payable {
        //test percent,should be complete by chainlink info
        uint256 user_RBT = msg.value.div(10**uint256(18)).mul(10).mul(10); //msg.value : wei
        //uint256 user_RBT = msg.value.div(10**uint(18)).mul( getLinkPriceBTC()).mul(10);
        //uint256 user_RBT = msg.value.div(10**uint(18)).mul( getLinkPriceETH()).mul(10);

        require(
            RBT_balances[msg.sender] + user_RBT < 2000000,
            "Purchase limit exceeded"
        );
        if (
            (user_RBT > 100000 && Not_First_buy[msg.sender] == false) ||
            (Not_First_buy[msg.sender] == true)
        ) {
            RBT_balances[msg.sender] = RBT_balances[msg.sender].add(user_RBT);

            totalRBT = totalRBT.sub(user_RBT);

            User_totalRBT = User_totalRBT.add(user_RBT);

            per_RBT_staking[msg.sender] = RBT_balances[msg.sender]
                .mul(SEEDROUND_STAKING_PERCENTAGE)
                .div(100);

            if (Not_First_buy[msg.sender] == false)
                //avoid same user be pushed several times
                addressIndices.push(msg.sender);

            Not_First_buy[msg.sender] = true;
        }
    }

    // give user part of staking every day
    function Run_per_RBT_staking() public onlyAdmin {
        require(now > staking_time + 1 days, "haven't pass a day");
        staking_time = staking_time.add(1 days);
        uint256 arrayLength = addressIndices.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            RBT_staking[addressIndices[i]] = RBT_staking[addressIndices[i]].add(
                per_RBT_staking[addressIndices[i]].div(365)
            ); //divide it to 365
        }
    }

    function withdraw_fromAdmin() public onlyAdmin {
        admin.transfer(address(this).balance);
    }

    function EndSeedRound() public onlyAdmin {
        //after public sale(about 1 year)(cliff start)
        saleEnd = now;
        uint256 arrayLength = addressIndices.length;
        for (uint256 i = 0; i < arrayLength; i++) {
            //move RBT from RBT_staking to Available_RBT
            Available_RBT[addressIndices[i]] = RBT_staking[addressIndices[i]];
            RBT_staking[addressIndices[i]] = 0;
        }
    }

    function vested() public onlyAdmin {
        //cliff end and vested start
        uint256 arrayLength = addressIndices.length;
        if (RBT_balances_available == false) {
            require(now > saleEnd + 365 days, "still in cliff"); //after cliff period
            RBT_balances_available = true;
            vested_record = now; // = saleEnd + 1 years;

            for (uint256 s = 0; s < arrayLength; s++) {
                //store the RBT_balances_per_vested
                RBT_balances_per_vested[addressIndices[s]] = RBT_balances[
                    addressIndices[s]
                ].div(VESTED_PERIOD);
            }
        } else {
            //vested per period
            if (
                now >= vested_record + SECONDS_PER_LOCK_PERIOD &&
                vested_period_cnt < VESTED_PERIOD
            ) {
                vested_record = vested_record.add(SECONDS_PER_LOCK_PERIOD); //renew vested_record

                vested_period_cnt = vested_period_cnt.add(1);

                for (uint256 i = 0; i < arrayLength; i++) {
                    //move RBT from RBT_balances to Available_RBT
                    Available_RBT[addressIndices[i]] = Available_RBT[
                        addressIndices[i]
                    ].add(RBT_balances[addressIndices[i]].div(VESTED_PERIOD));
                    RBT_balances[addressIndices[i]] = RBT_balances[
                        addressIndices[i]
                    ].sub(RBT_balances_per_vested[addressIndices[i]]);
                }
            }
        }
    }

    function withdraw(address user) public {
        balances[user] = balances[user].add(Available_RBT[user]); //put balance on metamask
        Available_RBT[user] = 0;
    }

    //---------------------------------------------------------------------------------------------------------------------
    function Contract_balance() public view returns (uint256) {
        return address(this).balance;
    }

    function renew_percentage() public {
        // percentage = 20->20%
        percentage = User_totalRBT.mul(100).div(initial_totalRBT);
    }

    function Check_my_RBT() public view returns (uint256) {
        return RBT_balances[msg.sender];
    }
}
