// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// Inspired by Solmate: https://github.com/Rari-Capital/solmate
/// Developed originally by 0xBasset
/// Upgraded by <redacted>
/// Additions by Tsuki Labs: https://tsukiyomigroup.com/ :)

contract Oil {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /*///////////////////////////////////////////////////////////////
                             ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    address public impl_;
    address public ruler;
    address public treasury;
    address public uniPair;
    address public weth;

    uint256 public totalSupply;
    uint256 public startingTime;
    uint256 public baseTax;
    uint256 public minSwap;

    bool public paused;
    bool public swapping;

    ERC721Like public habibi;
    IERC721A public royals;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public isMinter;

    mapping(uint256 => uint256) public claims;

    mapping(address => Staker) internal stakers;

    uint256 public sellFee;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    uint256 public doubleBaseTimestamp;

    struct Habibi {
        uint256 stakedTimestamp;
        uint256 tokenId;
    }

    struct Royals {
        uint256 stakedTimestamp;
        uint256 tokenId;
    }

    struct Staker {
        Habibi[] habibiz;
        Royals[] royals;
        uint256 lastClaim;
    }

    struct Rescueable {
        address revoker;
        bool adminAllowedAsRevoker;
    }

    mapping(address => Rescueable) private rescueable;

    address public sushiswapPair;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Router02 public sushiswapV2Router;

    mapping(address => bool) public excludedFromFees;
    mapping(address => bool) public blockList;

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "OIL";
    }

    function symbol() external pure returns (string memory) {
        return "OIL";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function initialize(address habibi_,address royals_, address treasury_) external {
        
        ruler = msg.sender;
        treasury = treasury_;
        habibi = ERC721Like(habibi_);
        royals = IERC721A(royals_);
        sellFee = 15000;
        _status = _NOT_ENTERED;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transfer(address to, uint256 value) external whenNotPaused returns (bool) {
        require(!blockList[msg.sender], "Address Blocked");
        _transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external whenNotPaused returns (bool) {
        require(!blockList[msg.sender], "Address Blocked");
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }

        _transfer(from, to, value);

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                              STAKING
    //////////////////////////////////////////////////////////////*/

    function habibizOfStaker(address _staker) public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](stakers[_staker].habibiz.length);
        for (uint256 i = 0; i < stakers[_staker].habibiz.length; i++) {
            tokenIds[i] = stakers[_staker].habibiz[i].tokenId;
        }
        return tokenIds;
    }

    function royalsOfStaker(address _staker) public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](stakers[_staker].royals.length);
        for (uint256 i = 0; i < stakers[_staker].royals.length; i++) {
            tokenIds[i] = stakers[_staker].royals[i].tokenId;
        }
        return tokenIds;
    }

    function allStakedOfStaker(address _staker) public view returns (uint256[] memory, uint256[] memory) {
        return (habibizOfStaker(_staker), royalsOfStaker(_staker));
    }

    //stakeHabibiz
    function stake(uint256[] calldata _habibiz) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _habibiz.length; i++) {
            require(ERC721Like(habibi).ownerOf(_habibiz[i]) == msg.sender, "At least one Habibi is not owned by you.");
            ERC721Like(habibi).transferFrom(msg.sender, address(this), _habibiz[i]);

            stakers[msg.sender].habibiz.push(Habibi(block.timestamp, _habibiz[i]));
        }
    }
    
    function stakeAll(uint256[] calldata _habibiz, uint256[] calldata _royals) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _habibiz.length; i++) {
            require(ERC721Like(habibi).ownerOf(_habibiz[i]) == msg.sender, "At least one Habibi is not owned by you.");
            ERC721Like(habibi).transferFrom(msg.sender, address(this), _habibiz[i]);

            stakers[msg.sender].habibiz.push(Habibi(block.timestamp, _habibiz[i]));
        }

        for (uint256 i = 0; i < _royals.length; i++){
            require(royals.ownerOf(_royals[i]) == msg.sender, "At least one Royals is not owned by you.");
            royals.transferFrom(msg.sender, address(this), _royals[i]);

            stakers[msg.sender].royals.push(Royals(block.timestamp, _royals[i]));
        }
    }

    function stakeRoyals(uint256[] calldata _royalsTokenId) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _royalsTokenId.length; i++){
            require(royals.ownerOf(_royalsTokenId[i]) == msg.sender, "At least one Royals is not owned by you.");
            royals.transferFrom(msg.sender, address(this), _royalsTokenId[i]);

            stakers[msg.sender].royals.push(Royals(block.timestamp, _royalsTokenId[i]));
        }
    }

    function unstakeAllHabibiz() external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender,1);
        uint256[] memory tokenIds = habibizOfStaker(msg.sender);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ERC721Like(habibi).transferFrom(address(this), msg.sender, tokenIds[i]);
            tokenIds[i] = stakers[msg.sender].habibiz[i].tokenId;
        }
        removeIdsFromStaker(msg.sender, tokenIds, false);
        stakers[msg.sender].lastClaim = block.timestamp;
        _mint(msg.sender, oilRewards);
    }

    function unstakeAll() external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender,0);
        uint256[] memory HabibitokenIds;
        uint256[] memory RoyalstokenIds;
        (HabibitokenIds, RoyalstokenIds)= allStakedOfStaker(msg.sender);

        for (uint256 i = 0; i < HabibitokenIds.length; i++) {
            ERC721Like(habibi).transferFrom(address(this), msg.sender, HabibitokenIds[i]);
            HabibitokenIds[i] = stakers[msg.sender].habibiz[i].tokenId;
        }
        removeIdsFromStaker(msg.sender, HabibitokenIds, false);

        for (uint256 i = 0; i < RoyalstokenIds.length; i++) {
            royals.transferFrom(address(this), msg.sender, RoyalstokenIds[i]);
            RoyalstokenIds[i] = stakers[msg.sender].royals[i].tokenId;
        }
        removeIdsFromStaker(msg.sender, RoyalstokenIds,true);

        stakers[msg.sender].lastClaim = block.timestamp;
        _mint(msg.sender, oilRewards);
    }

    function unstakeAllRoyals() external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender,2);
        uint256[] memory tokenIds = royalsOfStaker(msg.sender);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            
            royals.transferFrom(address(this), msg.sender, tokenIds[i]);
            tokenIds[i] = stakers[msg.sender].royals[i].tokenId;
        }

        removeIdsFromStaker(msg.sender, tokenIds,true);
        stakers[msg.sender].lastClaim = block.timestamp;
        _mint(msg.sender, oilRewards);
    }

    function unstakeHabibizByIds(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender,1);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bool owned = false;
            for (uint256 j = 0; j < stakers[msg.sender].habibiz.length; j++) {
                if (stakers[msg.sender].habibiz[j].tokenId == _tokenIds[i]) {
                    owned = true;
                }
            }
            require(owned, "TOKEN NOT OWNED BY SENDER");
            ERC721Like(habibi).transferFrom(address(this), msg.sender, _tokenIds[i]);
        }
        removeIdsFromStaker(msg.sender, _tokenIds, false);
        stakers[msg.sender].lastClaim = block.timestamp;

        _mint(msg.sender, oilRewards);
    }
    
    function unstakeRoyalsByIds(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender,2);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bool owned = false;
            for (uint256 j = 0; j < stakers[msg.sender].royals.length; j++) {
                if (stakers[msg.sender].royals[j].tokenId == _tokenIds[i]) {
                    owned = true;
                }
            }
            require(owned, "TOKEN NOT OWNED BY SENDER");

            royals.transferFrom(address(this), msg.sender, _tokenIds[i]);
        }
        removeIdsFromStaker(msg.sender, _tokenIds,true);

        stakers[msg.sender].lastClaim = block.timestamp;

        _mint(msg.sender, oilRewards);
    }


    function removeIdsFromStaker(address staker_, uint256[] memory tokenIds_, bool isRoyal_) internal {
        if(!isRoyal_){
            for (uint256 i = 0; i < tokenIds_.length; i++) {
                for (uint256 j = 0; j < stakers[staker_].habibiz.length; j++) {
                    if (tokenIds_[i] == stakers[staker_].habibiz[j].tokenId) {
                        stakers[staker_].habibiz[j] = stakers[staker_].habibiz[stakers[staker_].habibiz.length - 1];
                        stakers[staker_].habibiz.pop();
                    }
                }
            }
        }
        else{
            for (uint256 i = 0; i < tokenIds_.length; i++) {
                for (uint256 j = 0; j < stakers[staker_].royals.length; j++) {
                    if (tokenIds_[i] == stakers[staker_].royals[j].tokenId) {
                        stakers[staker_].royals[j] = stakers[staker_].royals[stakers[staker_].royals.length - 1];
                        stakers[staker_].royals.pop();
                    }
                }
            }
        }
    }

    function approveRescue(
        address revoker_,
        bool confirm_,
        bool rescueableByAdmin_
    ) external {
        require(confirm_, "Did not confirm");
        require(revoker_ != address(0), "Revoker cannot be null address");
        rescueable[msg.sender] = Rescueable(revoker_, rescueableByAdmin_);
    }

    function revokeRescue(address rescueable_, bool confirm_) external {
        if (msg.sender == ruler) {
            require(rescueable[rescueable_].adminAllowedAsRevoker, "Admin is not allowed to revoke");
        } else {
            require(rescueable[rescueable_].revoker == msg.sender, "Sender is not revoker");
        }
        require(confirm_, "Did not confirm");

        delete rescueable[rescueable_];
    }

    /*////////////////////////////////////////////////////////////
                        Habibis Burn
    ////////////////////////////////////////////////////////////*/

    function burnHabibizForRoyals(address user, uint256[] calldata _tokenIds) external returns (bool){
        require(msg.sender == address(royals), "You do not have permission to call this function");
        
        uint256[] memory habibzStaked = habibizOfStaker(user);

        uint256 j = 0;
        uint256 i = 0;
        bool exists = true;
        for (i = 0; i < _tokenIds.length; i++) {
            for (j = 0 ; j < habibzStaked.length; j++){
                if (_tokenIds[i] == habibzStaked[j]){
                    break;
                }
            }
 
            if (j == habibzStaked.length){
                exists = false;
            }
            require(exists,"One of your habibiz is not staked");   
        }

        removeIdsFromStaker(user, _tokenIds,false);

        return true;
    }

    /*///////////////////////////////////////////////////////////////
                              CLAIMING
    //////////////////////////////////////////////////////////////*/

    function claim() external nonReentrant whenNotPaused {
        require(!blockList[msg.sender], "Address Blocked");
        uint256 oil = calculateOilRewards(msg.sender,0);
        if (oil > 0) {
            stakers[msg.sender].lastClaim = block.timestamp;
            _mint(msg.sender, oil);
        } else {
            revert("Not enough oil");
        }
    }

    /*///////////////////////////////////////////////////////////////
                            OIL REWARDS
    //////////////////////////////////////////////////////////////*/

    function calculateOilRewards(address _staker, uint256 NFTType_) public view returns (uint256 oilAmount) {
        uint256 balanceBonus = holderBonusPercentage(_staker);
        uint256 royalsBase = getRoyalsBase(_staker);
        if(NFTType_ == 0 || NFTType_ == 1){
            for (uint256 i = 0; i < stakers[_staker].habibiz.length; i++) {
                uint256 habibiId = stakers[_staker].habibiz[i].tokenId;
                oilAmount =
                    oilAmount +
                    calculateOilOfStaker(
                        habibiId,
                        stakers[_staker].lastClaim,
                        stakers[_staker].habibiz[i].stakedTimestamp,
                        block.timestamp,
                        balanceBonus,
                        doubleBaseTimestamp,
                        false,
                        royalsBase
                    );
            }
        }
        
        if(NFTType_ == 0 || NFTType_ == 2){
            for (uint256 i = 0; i < stakers[_staker].royals.length; i++) {
                uint256 habibiId = stakers[_staker].royals[i].tokenId;
                oilAmount =
                    oilAmount +
                    calculateOilOfStaker(
                        habibiId,
                        stakers[_staker].lastClaim,
                        stakers[_staker].royals[i].stakedTimestamp,
                        block.timestamp,
                        balanceBonus,
                        doubleBaseTimestamp,
                        true,
                        royalsBase
                    );
            }
        }
    }


    function calculateOilOfStaker(
        uint256 _habibiId,
        uint256 _lastClaimedTimestamp,
        uint256 _stakedTimestamp,
        uint256 _currentTimestamp,
        uint256 _balanceBonus,
        uint256 _doubleBaseTimestamp,
        bool _isRoyal,
        uint256 royalsBase
    ) internal pure returns (uint256 oil) {
        uint256 bonusPercentage;
        uint256 baseOilMultiplier = 1;
        uint256 unclaimedTime;
        uint256 stakedTime = _currentTimestamp - _stakedTimestamp;
        if (_lastClaimedTimestamp < _stakedTimestamp) {
            _lastClaimedTimestamp = _stakedTimestamp;
        }
       
        unclaimedTime = _currentTimestamp - _lastClaimedTimestamp;

        if ((stakedTime >= 15 days || _stakedTimestamp <= _doubleBaseTimestamp) && !_isRoyal) {
            baseOilMultiplier = 2;
        }

        if (stakedTime >= 90 days) {
            bonusPercentage = 100;
        } else {
            for (uint256 i = 2; i < 4; i++) {
                uint256 timeRequirement = 15 days * i;
                if (timeRequirement > 0 && timeRequirement <= stakedTime) {
                    bonusPercentage = bonusPercentage + 15;
                } else {
                    break;
                }
            }
        }

        if (_isRoyal) {
            if (stakedTime >= 30 days && stakedTime < 60 days) {
                bonusPercentage = 15;
            } else if (stakedTime >= 60 days && stakedTime < 90 days) {
                bonusPercentage = 30;
            } else if (stakedTime >= 90 days) {
                bonusPercentage = 100;
            }
            oil = (unclaimedTime * royalsBase * 1 ether * baseOilMultiplier) / 1 days;
            oil = oil + ((oil * bonusPercentage) / 100);
        } else if (_isAnimated(_habibiId)) {
            oil = (unclaimedTime * 2500 ether * baseOilMultiplier) / 1 days;
        } else {
            bonusPercentage = bonusPercentage + _balanceBonus;
            oil = (unclaimedTime * 500 ether * baseOilMultiplier) / 1 days;
        }

    }

    function getRoyalsBase(address _staker) internal view returns(uint256) {
        uint256 base;
        if(stakers[_staker].royals.length == 1){
            base = 12000;
        } else if(stakers[_staker].royals.length == 2){
            base = 13500;
        } else if(stakers[_staker].royals.length >= 3){
            base = 15000;
        }
        return base;
    }

    function staker(address staker_) public view returns (Staker memory) {
        return stakers[staker_];
    }

    /*///////////////////////////////////////////////////////////////
                            OIL PRIVILEGE
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 value) external onlyMinter {
        _mint(to, value);
    }

    function burn(address from, uint256 value) external onlyMinter {
        _burn(from, value);
    }

    /*///////////////////////////////////////////////////////////////
                         Ruler Function
    //////////////////////////////////////////////////////////////*/

    function setDoubleBaseTimestamp(uint256 _doubleBaseTimestamp) external onlyRuler {
        doubleBaseTimestamp = _doubleBaseTimestamp;
    }

    function setMinter(address _minter, bool _canMint) external onlyRuler {
        isMinter[_minter] = _canMint;
    }

    function setRuler(address _ruler) external onlyRuler {
        ruler = _ruler;
    }

    function setPaused(bool _paused) external onlyRuler {
        paused = _paused;
    }

    function setHabibiAddress(address _habibiAddress) external onlyRuler {
        habibi = ERC721Like(_habibiAddress);
    }

    function setSellFee(uint256 _fee) external onlyRuler {
        sellFee = _fee;
    }

    function setUniswapV2Router(address router_) external onlyRuler {
        uniswapV2Router = IUniswapV2Router02(router_);
    }

    function setSushiswapV2Router(address router_) external onlyRuler {
        sushiswapV2Router = IUniswapV2Router02(router_);
    }

    function setV2Routers(address uniswapRouter_, address sushiswapRouter_) external onlyRuler {
        uniswapV2Router = IUniswapV2Router02(uniswapRouter_);
        sushiswapV2Router = IUniswapV2Router02(sushiswapRouter_);
    }

    function setUniPair(address uniPair_) external onlyRuler {
        uniPair = uniPair_;
    }

    function setSushiswapPair(address sushiswapPair_) external onlyRuler {
        sushiswapPair = sushiswapPair_;
    }

    function setPairs(address uniPair_, address sushiswapPair_) external onlyRuler {
        uniPair = uniPair_;
        sushiswapPair = sushiswapPair_;
    }

    function excludeFromFees(address[] calldata addresses_, bool[] calldata excluded_) external onlyRuler {
        for (uint256 i = 0; i < addresses_.length; i++) {
            excludedFromFees[addresses_[i]] = excluded_[i];
        }
    }

    function blockOrUnblockAddresses(address[] calldata addresses_, bool[] calldata blocked_) external onlyRuler {
        for (uint256 i = 0; i < addresses_.length; i++) {
            blockList[addresses_[i]] = blocked_[i];
        }
    }

    /// emergency
    function rescue(
        address staker_,
        address to_,
        uint256[] calldata tokenIds_
    ) external onlyRuler {
        require(rescueable[staker_].revoker != address(0), "User has not opted-in for rescue");
        uint256[] memory fromHabibiz = habibizOfStaker(staker_);
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            bool found;
            for (uint256 j = 0; j < fromHabibiz.length; j++) {
                if (tokenIds_[i] == fromHabibiz[j]) {
                    found = true;
                    break;
                }
            }
            require(found, "TokenID not found");
        }
        removeIdsFromStaker(staker_, tokenIds_, false);
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            stakers[to_].habibiz.push(Habibi(block.timestamp, tokenIds_[i]));
        }
    }

    /*///////////////////////////////////////////////////////////////
                          INTERNAL UTILS
    //////////////////////////////////////////////////////////////*/

    function _getRouterFromPair(address pairAddress_) internal view returns (IUniswapV2Router02) {
        return pairAddress_ == address(uniPair) ? uniswapV2Router : sushiswapV2Router;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        require(balanceOf[from] >= value, "ERC20: transfer amount exceeds balance");
        uint256 tax;

        bool shouldTax = ((to == uniPair && balanceOf[to] != 0) || (to == sushiswapPair && balanceOf[to] != 0)) &&
            !swapping;
        if (shouldTax && !excludedFromFees[from]) {
            tax = (value * sellFee) / 100_000;
            if (tax > 0) {
                balanceOf[address(this)] += tax;
                swapTokensForEth(to, tax, treasury);
            }
        }
        uint256 taxedAmount = value - tax;
        balanceOf[from] -= value;
        balanceOf[to] += taxedAmount;
        emit Transfer(from, to, taxedAmount);
    }

    function swapTokensForEth(
        address pairAddress_,
        uint256 _amountIn,
        address _to
    ) private lockTheSwap {
        IUniswapV2Router02 router = _getRouterFromPair(pairAddress_);
        IERC20(address(this)).approve(address(router), _amountIn);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH(); // or router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(_amountIn, 1, path, _to, block.timestamp);
    }

    function _mint(address to, uint256 value) internal {
        totalSupply += value;

        // This is safe because the sum of all user
        // balances can't exceed type(uint256).max!
        unchecked {
            balanceOf[to] += value;
        }

        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;

        // This is safe because a user won't ever
        // have a balance larger than totalSupply!
        unchecked {
            totalSupply -= value;
        }

        emit Transfer(from, address(0), value);
    }

    function holderBonusPercentage(address staker_) public view returns (uint256) {
        uint256 balance = stakers[staker_].habibiz.length;

        if (balance < 5) return 0;
        if (balance < 10) return 15;
        if (balance < 20) return 25;
        return 35;
    }

    function _isAnimated(uint256 _id) internal pure returns (bool animated) {
        return
            _id == 40 ||
            _id == 108 ||
            _id == 169 ||
            _id == 191 ||
            _id == 246 ||
            _id == 257 ||
            _id == 319 ||
            _id == 386 ||
            _id == 496 ||
            _id == 562 ||
            _id == 637 ||
            _id == 692 ||
            _id == 832 ||
            _id == 942 ||
            _id == 943 ||
            _id == 957 ||
            _id == 1100 ||
            _id == 1108 ||
            _id == 1169 ||
            _id == 1178 ||
            _id == 1627 ||
            _id == 1706 ||
            _id == 1843 ||
            _id == 1884 ||
            _id == 2137 ||
            _id == 2158 ||
            _id == 2165 ||
            _id == 2214 ||
            _id == 2232 ||
            _id == 2238 ||
            _id == 2508 ||
            _id == 2629 ||
            _id == 2863 ||
            _id == 3055 ||
            _id == 3073 ||
            _id == 3280 ||
            _id == 3297 ||
            _id == 3322 ||
            _id == 3327 ||
            _id == 3361 ||
            _id == 3411 ||
            _id == 3605 ||
            _id == 3639 ||
            _id == 3774 ||
            _id == 4250 ||
            _id == 4267 ||
            _id == 4302 ||
            _id == 4362 ||
            _id == 4382 ||
            _id == 4397 ||
            _id == 4675 ||
            _id == 4707 ||
            _id == 4863;
    }

    /*///////////////////////////////////////////////////////////////
                          MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyMinter() {
        require(isMinter[msg.sender], "FORBIDDEN TO MINT OR BURN");
        _;
    }

    modifier onlyRuler() {
        require(msg.sender == ruler, "NOT ALLOWED TO RULE");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

interface IERC721A {
    function transferFrom(
    address from,
    address to,
    uint256 tokenId
    ) external ;

    function ownerOf(uint256 tokenId) external returns (address);
}


interface ERC721Like {
    function balanceOf(address holder_) external view returns (uint256);

    function ownerOf(uint256 id_) external view returns (address);

    function walletOfOwner(address _owner) external view returns (uint256[] calldata);

    function isApprovedForAll(address operator_, address address_) external view returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface UniPairLike {
    function token0() external returns (address);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}