// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is ReentrancyGuard, Ownable {
    constructor() Ownable(msg.sender) {
        stakeholders.push();
        plans.flexiblePlans.push();
    }

    struct FlexiblePlan {
        string token;
        uint256 ratePerSecond;
        uint256 minQuantityPerUser;
        uint256 maxQuantityPerUser;
        uint256 maxStakeableQuantity;
        uint256 endDate;
        uint256 totalStaked;
    }

    struct Plans {
        FlexiblePlan[] flexiblePlans;
    }

    struct UserFlexiblePlan {
        string token;
        uint256 ratePerSecond;
        uint256 quantity;
        uint256 startDate;
        uint256 endDate;
        uint256 interestAccumulated;
        bool active;
    }


    struct Stakeholder {
        address userAddr;
        UserFlexiblePlan[] flexiblePlans;
        
    }

    mapping(string => address) public mapTokenToContractAddress;
    mapping(address => mapping(uint256 => uint256))
        mapUserPlanIdToFlexiblePlanIndex;
    mapping(address => uint256) addressToStakeholderIndex;
    Plans private plans;
    Stakeholder[] private stakeholders;

    function AddTokenAndAddress(string memory _token, address _contractAddress)
        external
        onlyOwner
    {
        mapTokenToContractAddress[_token] = _contractAddress;
    }

    function CreateFlexibleStakingPlan(
        string memory _token,
        uint256 _ratePerSecond,
        uint256 _minQuantityPerUser,
        uint256 _maxQuantityPerUser,
        uint256 _maxStakeableAmount,
        uint256 _endDate
    ) external onlyOwner {
        require(
            mapTokenToContractAddress[_token] != address(0x00),
            "token is not added"
        );
        require(
            _endDate > block.timestamp,
            "end date cannot be earlier than the current date"
        );
        plans.flexiblePlans.push();
        uint256 index = plans.flexiblePlans.length - 1;
        plans.flexiblePlans[index] = FlexiblePlan(
            _token,
            _ratePerSecond,
            _minQuantityPerUser,
            _maxQuantityPerUser,
            _maxStakeableAmount,
            _endDate,
            0
        );
    }

    function StakeInFlexiblePlan(uint256 _planId, uint256 _quantity) external {
        // planId is nothing but index in the array
        require(_planId < plans.flexiblePlans.length, "invalid plan ID");
        uint256 currentTime = block.timestamp;
        // read only
        FlexiblePlan memory flexiblePlan = plans.flexiblePlans[_planId];
        require(flexiblePlan.endDate > currentTime, "plan is expired");
        require(
            _quantity >= flexiblePlan.minQuantityPerUser,
            "minimum quantity per user criteria not met"
        );
        require(
            flexiblePlan.maxStakeableQuantity >=
                flexiblePlan.totalStaked + _quantity,
            "maximum stakeable quantity exceeds"
        );

        uint256 index = addressToStakeholderIndex[msg.sender];
        if (index == 0) {
            // doesn't exist, add
            index = AddStakeholder(msg.sender);
        }

        uint256 userPlanIndex = mapUserPlanIdToFlexiblePlanIndex[msg.sender][
            _planId
        ];
        // read only
        UserFlexiblePlan memory userFlexiblePlan = stakeholders[index]
            .flexiblePlans[userPlanIndex];
        require(
            userFlexiblePlan.quantity + _quantity <=
                flexiblePlan.maxQuantityPerUser,
            "maximum quantity per user criteria not met"
        );

        IERC20 contractAddr = IERC20(
            mapTokenToContractAddress[flexiblePlan.token]
        );

        contractAddr.transferFrom(msg.sender, address(this), _quantity);

        if (
            userFlexiblePlan.quantity + userFlexiblePlan.interestAccumulated > 0
        ) {
            
        uint256 totalInterest = GetTotalInterestFlexiblePlan(msg.sender,_planId);
            userFlexiblePlan.interestAccumulated =
               totalInterest;
            userFlexiblePlan.quantity += _quantity;
            userFlexiblePlan.startDate = currentTime;

            stakeholders[index].flexiblePlans[userPlanIndex] = userFlexiblePlan;
        } else {
            stakeholders[index].flexiblePlans.push(
                UserFlexiblePlan(
                    flexiblePlan.token,
                    flexiblePlan.ratePerSecond,
                    _quantity,
                    currentTime,
                    flexiblePlan.endDate,
                    0,
                    true
                )
            );

            mapUserPlanIdToFlexiblePlanIndex[msg.sender][_planId] =
                stakeholders[index].flexiblePlans.length -
                1;
        }

        plans.flexiblePlans[_planId].totalStaked =
            flexiblePlan.totalStaked +
            _quantity;
    }

    function UnstakeInFlexiblePlan(uint256 _planId, uint256 _quantity)
        external
        nonReentrant
    {
        uint256 index = addressToStakeholderIndex[msg.sender];
        require(
            index > 0,
            "only stakers are allowed to perform this operation"
        );
        uint256 currentTime = block.timestamp;
        FlexiblePlan memory flexiblePlan = plans.flexiblePlans[_planId];
        uint256 userPlanIndex = mapUserPlanIdToFlexiblePlanIndex[msg.sender][
            _planId
        ];
        UserFlexiblePlan memory userFlexiblePlan = stakeholders[index]
            .flexiblePlans[userPlanIndex];
        require(userFlexiblePlan.active == true, "user is not active");
        IERC20 contractAddr = IERC20(
            mapTokenToContractAddress[flexiblePlan.token]
        );

        // calculate current interest
        uint256 totalInterest = GetTotalInterestFlexiblePlan(msg.sender,_planId);
        uint256 withdrawableQty;
        if (userFlexiblePlan.endDate <= currentTime) {
            // plan is expired, transfer all the funds along with interest
            userFlexiblePlan.interestAccumulated = totalInterest;
            withdrawableQty =
                userFlexiblePlan.quantity +
                userFlexiblePlan.interestAccumulated;
            require(_quantity <= withdrawableQty, "not enough funds");
            userFlexiblePlan.active = false;
        } else {
            // plan is not expired, user can only unstake deposited quantity
            withdrawableQty = _quantity;
            require(_quantity <= userFlexiblePlan.quantity, "not enough funds");
            userFlexiblePlan.quantity -= _quantity;
            userFlexiblePlan.startDate = currentTime;
            userFlexiblePlan.interestAccumulated = totalInterest;
            plans.flexiblePlans[_planId].totalStaked -= _quantity;
        }
        contractAddr.transfer(msg.sender, withdrawableQty);
        stakeholders[index].flexiblePlans[userPlanIndex] = userFlexiblePlan;
    }

    function AddStakeholder(address _address) private returns (uint256) {
        // Push a empty item to the Array to make space for our new stakeholder
        stakeholders.push();
        uint256 userIndex = stakeholders.length - 1;
        // Assign the address to the new index
        stakeholders[userIndex].userAddr = _address;
        // Hack
        stakeholders[userIndex].flexiblePlans.push();
        // Add index to the stakeHolders
        addressToStakeholderIndex[_address] = userIndex;
        return userIndex;
    }

    function GetStakeholder(address _address)
        external
        view
        returns (Stakeholder memory)
    {
        uint256 index = addressToStakeholderIndex[_address];
        return stakeholders[index];
    }

    function GetPlans() external view returns (Plans memory) {
        return plans;
    }

    function GetTotalInterestFlexiblePlan(address _address, uint256 _planId)
        public
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;
        uint256 userPlanIndex = mapUserPlanIdToFlexiblePlanIndex[_address][
            _planId
        ];
        uint256 index = addressToStakeholderIndex[_address];
        UserFlexiblePlan memory userFlexiblePlan = stakeholders[index]
            .flexiblePlans[userPlanIndex];
        uint256 currentAccumulatedInterest = 0;
        if (currentTime >= userFlexiblePlan.endDate) {
            currentAccumulatedInterest =
                ((userFlexiblePlan.endDate - userFlexiblePlan.startDate) *
                    userFlexiblePlan.quantity *
                    userFlexiblePlan.ratePerSecond) /
                (10**20);
        } else {
            currentAccumulatedInterest =
                ((currentTime - userFlexiblePlan.startDate) *
                    userFlexiblePlan.quantity *
                    userFlexiblePlan.ratePerSecond) /
                (10**20);
        }
        return
            currentAccumulatedInterest + userFlexiblePlan.interestAccumulated;
    }

    function StuckBalance(address to, address _token, uint _quantity)external onlyOwner{
        IERC20 token = IERC20(_token);
        token.transfer(to, _quantity);
    }
}