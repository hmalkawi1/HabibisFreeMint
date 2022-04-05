// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "erc721a/contracts/ERC721A.sol";

import "hardhat/console.sol";
/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// Inspired by Solmate: https://github.com/Rari-Capital/solmate
/// Developed originally by 0xBasset
/// Upgraded by <redacted>

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
    address public ruler = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
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
    ERC721A public royals;

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
    /*/////////////////////////////////////////////////////////////
                        Tsuki Lab Addition
    ////////////////////////////////////////////////////////////*/

    IUniswapV2Router02 public uniswapV2Router;

    bool public isliquidtyAdd;

    address public royalsAddress;

    /*/////////////////////////////////////////////////////////////
                        Tsuki Lab Addition END
    ////////////////////////////////////////////////////////////*/


    struct Habibi {
        uint256 stakedTimestamp;
        uint256 tokenId;
    }

    struct Staker {
        Habibi[] habibiz;
        uint256 lastClaim;
    }

    struct Royals {
        uint256 stakedTimestamp;
        uint256 tokenId;
    }
    struct RoyalsStaker {
        Royals[] royals;
        uint256 lastClaim;
        uint256 timestamp;
        uint256 base;
    }

     // map staker address to stake details
    mapping(address => RoyalsStaker) public royalsStaker;
    mapping(address => RoyalsStaker) internal royalsStakers;

    // map staker to total staking time 
    mapping(address => uint256) public stakingTimeRoyals;

    /*/////////////////////////////////////////////////////////////
                        Tsuki Lab Addition
    ////////////////////////////////////////////////////////////*/
    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    modifier lockAddingLiquidity {
        isliquidtyAdd = true;
        _;
        isliquidtyAdd = false;
    }

    /*/////////////////////////////////////////////////////////////
                        Tsuki Lab Addition END
    ////////////////////////////////////////////////////////////*/

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

    function initialize(address habibi_, address treasury_) external {
        require(msg.sender == ruler, "NOT ALLOWED TO RULE");
        ruler = msg.sender;
        treasury = treasury_;
        habibi = ERC721Like(habibi_);
        sellFee = 15;
        _status = _NOT_ENTERED;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transfer(address to, uint256 value) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external whenNotPaused returns (bool) {
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

    function stake(uint256[] calldata _habibiz) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _habibiz.length; i++) {
            require(ERC721Like(habibi).ownerOf(_habibiz[i]) == msg.sender, "At least one Habibi is not owned by you.");
            ERC721Like(habibi).transferFrom(msg.sender, address(this), _habibiz[i]);

            stakers[msg.sender].habibiz.push(Habibi(block.timestamp, _habibiz[i]));
        }
    }

    function unstakeAll() external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender);
        uint256[] memory tokenIds = habibizOfStaker(msg.sender);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ERC721Like(habibi).transferFrom(address(this), msg.sender, tokenIds[i]);
            tokenIds[i] = stakers[msg.sender].habibiz[i].tokenId;
        }
        removeHabibiIdsFromStaker(msg.sender, tokenIds);
        stakers[msg.sender].lastClaim = block.timestamp;
        _mint(msg.sender, oilRewards);
    }

    function removeHabibiIdsFromStaker(address _staker, uint256[] memory _tokenIds) internal {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            for (uint256 j = 0; j < stakers[_staker].habibiz.length; j++) {
                if (_tokenIds[i] == stakers[_staker].habibiz[j].tokenId) {
                    stakers[_staker].habibiz[j] = stakers[_staker].habibiz[stakers[_staker].habibiz.length - 1];
                    stakers[_staker].habibiz.pop();
                }
            }
        }
    }

    function unstakeByIds(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateOilRewards(msg.sender);
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
        removeHabibiIdsFromStaker(msg.sender, _tokenIds);
        stakers[msg.sender].lastClaim = block.timestamp;

        _mint(msg.sender, oilRewards);
    }

    /*////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////*/

    function setRoyalsAddress(address _royalsAddress) public onlyRuler{
        royalsAddress = _royalsAddress;
    }

    function burnHabibizForRoyals(address user, uint256[] calldata _tokenIds) external returns (bool){
        require(msg.sender == royalsAddress, "You do not have permission to call this function");
        
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

        removeHabibiIdsFromStaker(user, _tokenIds);

        return true;
    }

     /*/////////////////////////////////////////////////////
                    Royals Staking and rewards
    ////////////////////////////////////////////////////*/

    function royalsOfStaker(address _staker) public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](royalsStakers[_staker].royals.length);
        for (uint256 i = 0; i < royalsStakers[_staker].royals.length; i++) {
            tokenIds[i] = royalsStakers[_staker].royals[i].tokenId;
        }
        return tokenIds;
    }

    function removeRoyalsIdsFromStaker(address _staker, uint256[] memory _tokenIds) internal {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            for (uint256 j = 0; j < royalsStakers[_staker].royals.length; j++) {
                if (_tokenIds[i] == royalsStakers[_staker].royals[j].tokenId) {
                    royalsStakers[_staker].royals[j] = royalsStakers[_staker].royals[royalsStakers[_staker].royals.length - 1];
                    royalsStakers[_staker].royals.pop();
                }
            }
        }
    }

    function unstakeRoyalsByIds(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        //must get rewards of given NFTs
        //require(user is not sending all staked nfts, "you should unstakeAll() instead")
        //do double forloop to find nfts user is wanting to unstake, then calculate.
        uint256 oilRewards = calculateRoyalsOilRewards(msg.sender);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            bool owned = false;
            for (uint256 j = 0; j < royalsStakers[msg.sender].royals.length; j++) {
                if (royalsStakers[msg.sender].royals[j].tokenId == _tokenIds[i]) {
                    owned = true;
                }
            }
            require(owned, "TOKEN NOT OWNED BY SENDER");
           
            ERC721A(royals).transferFrom(address(this), msg.sender, _tokenIds[i]);
        }
        removeRoyalsIdsFromStaker(msg.sender, _tokenIds);
        
        royalsStaker[msg.sender].lastClaim = block.timestamp;

        _mint(msg.sender, oilRewards);

        if(royalsStaker[msg.sender].royals.length == 0){
            royalsStaker[msg.sender].base = 0;
        }
        if(royalsStaker[msg.sender].royals.length == 1){
                royalsStaker[msg.sender].base = 12000;
        }
        if(royalsStaker[msg.sender].royals.length == 2){
            royalsStaker[msg.sender].base = 13500;
        }
        if(royalsStaker[msg.sender].royals.length >= 3){
            royalsStaker[msg.sender].base = 15000;
        }

        
    }

    function stakeRoyals(uint256[] calldata _royalsTokenId) external nonReentrant whenNotPaused {

        for (uint256 i = 0; i < _royalsTokenId.length; i++){
            
            require(royals.ownerOf(_royalsTokenId[i]) == msg.sender, "At least one Royals is not owned by you.");

            royals.transferFrom(msg.sender, address(this), _royalsTokenId[i]);

            royalsStaker[msg.sender].royals.push(Royals(block.timestamp, _royalsTokenId[i]));
        }

        //set base based on how many nfts user has staked
        if(royalsStaker[msg.sender].royals.length == 1){
                royalsStaker[msg.sender].base = 12000;
        }
        if(royalsStaker[msg.sender].royals.length == 2){
            royalsStaker[msg.sender].base = 13500;
        }
        if(royalsStaker[msg.sender].royals.length >= 3){
            royalsStaker[msg.sender].base = 15000;
        }
        

    } 

    function unstakeAllRoyals() external nonReentrant whenNotPaused {
        uint256 oilRewards = calculateRoyalsOilRewards(msg.sender);
        uint256[] memory tokenIds = royalsOfStaker(msg.sender);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ERC721A(royals).transferFrom(address(this), msg.sender, tokenIds[i]);
            tokenIds[i] = royalsStakers[msg.sender].royals[i].tokenId;
        }
        removeRoyalsIdsFromStaker(msg.sender, tokenIds);
        //This needs modification since we dont save last Claim?
        royalsStakers[msg.sender].lastClaim = block.timestamp;
        _mint(msg.sender, oilRewards);
        //reset their base
        royalsStaker[msg.sender].base = 0;
    }

    function calculateRoyalsOilRewards(address _staker) public view returns (uint256 oilAmount) {
    
        for (uint256 i = 0; i < royalsStakers[_staker].royals.length; i++) {
           uint256 royalsId = royalsStakers[_staker].royals[i].tokenId;
            oilAmount =
                oilAmount +
                calculateOilOfRoyals(
                    royalsStakers[_staker].lastClaim,
                    royalsStakers[_staker].royals[i].stakedTimestamp,
                    block.timestamp,
                    royalsStaker[_staker].base
                );
        }
    }

    function calculateOilOfRoyals(      
        uint256 _lastClaimedTimestamp,
        uint256 _stakedTimestamp,
        uint256 _currentTimestamp,
        uint256 _base
    ) internal pure returns (uint256 oil) {
        uint256 bonusPercentage;
        uint256 unclaimedTime;
        uint256 stakedTime = _currentTimestamp - _stakedTimestamp;
        if (_lastClaimedTimestamp < _stakedTimestamp) {
            _lastClaimedTimestamp = _stakedTimestamp;
        }

        unclaimedTime = _currentTimestamp - _lastClaimedTimestamp;

        if (stakedTime >= 30 days && stakedTime < 60 days) {
            bonusPercentage = 15;
        }

        if (stakedTime >= 60 days && stakedTime < 90 days) {
            bonusPercentage = 30;
        }

        if (stakedTime >= 90 days) {
            bonusPercentage = 100;
        }

        oil = (unclaimedTime * 1 ether * _base) / 1 days;
        oil = oil + ((oil * bonusPercentage) / 100);
    }
    

    function claimRoyal() external nonReentrant whenNotPaused {
        uint256 oil = calculateRoyalsOilRewards(msg.sender);
        if (oil > 0) {
            royalsStakers[msg.sender].lastClaim = block.timestamp;
            _mint(msg.sender, oil);
        } else {
            revert("Not enough oil");
        }
    }

    /*///////////////////////////////////////////////////////////////
                              CLAIMING
    //////////////////////////////////////////////////////////////*/
    function claim() external nonReentrant whenNotPaused {
        uint256 oil = calculateOilRewards(msg.sender);
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

    function calculateOilRewards(address _staker) public view returns (uint256 oilAmount) {
        uint256 balanceBonus = _getBonusPct();
        for (uint256 i = 0; i < stakers[_staker].habibiz.length; i++) {
            uint256 habibiId = stakers[_staker].habibiz[i].tokenId;
            oilAmount =
                oilAmount +
                calculateOilOfHabibi(
                    habibiId,
                    stakers[_staker].lastClaim,
                    stakers[_staker].habibiz[i].stakedTimestamp,
                    block.timestamp,
                    balanceBonus,
                    doubleBaseTimestamp
                );
        }
    }

    function calculateOilOfHabibi(
        uint256 _habibiId,
        uint256 _lastClaimedTimestamp,
        uint256 _stakedTimestamp,
        uint256 _currentTimestamp,
        uint256 _balanceBonus,
        uint256 _doubleBaseTimestamp
    ) internal pure returns (uint256 oil) {
        uint256 bonusPercentage;
        uint256 baseOilMultiplier = 1;
        uint256 unclaimedTime;
        uint256 stakedTime = _currentTimestamp - _stakedTimestamp;
        if (_lastClaimedTimestamp < _stakedTimestamp) {
            _lastClaimedTimestamp = _stakedTimestamp;
        }

        unclaimedTime = _currentTimestamp - _lastClaimedTimestamp;

        if (stakedTime >= 15 days || _stakedTimestamp <= _doubleBaseTimestamp) {
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

        if (_isAnimated(_habibiId)) {
            oil = (unclaimedTime * 2500 ether * baseOilMultiplier) / 1 days;
        } else {
            bonusPercentage = bonusPercentage + _balanceBonus;
            oil = (unclaimedTime * 500 ether * baseOilMultiplier) / 1 days;
        }
        oil = oil + ((oil * bonusPercentage) / 100);
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

    /*///////////////////////////////////////////////////////////////
                          INTERNAL UTILS
    //////////////////////////////////////////////////////////////*/


    /*/////////////////////////////////////////////////////////////
                            start of Tsuki Lab Addition
    ////////////////////////////////////////////////////////////*/

    function setUniRouter(address _router) public onlyRuler{
        //sushiswap router: 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        uniswapV2Router = _uniswapV2Router;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        require(balanceOf[from] >= value, "ERC20: transfer amount exceeds balance");
        uint256 tax = 0;

        if ( (from != uniPair && to != uniPair)) {
            tax = 0;
        } else {

            //Set Fee for Sells & not when adding liquidity
            if (to == uniPair && from != address(uniswapV2Router) && !isliquidtyAdd) { 
               tax = (value * sellFee) / 100_000;

               if (!swapping && from != uniPair && tax > 0){
                   balanceOf[address(this)] += tax;
                   swapTokensForEth(tax, treasury);
               }
            }
            
        }

        balanceOf[from] -= value;
        uint256 amountAfterTax = value - tax;
        balanceOf[to] += amountAfterTax;
        emit Transfer(from, to, amountAfterTax); 
    }

    //only owner function
    function setUniPair(address _uniPair) public onlyRuler{
        uniPair = _uniPair;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function swapTokensForEth(uint256 _amountIn, address _to) private lockTheSwap {
        IERC20(address(this)).approve(address(uniswapV2Router), _amountIn);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH(); // or uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amountIn,
            1,
            path,
            _to,
            block.timestamp
        );
    }

    //UI must approve the users WETH: Weth.approve(oilContract, amount);
    function addliquidity(uint256 _oilAmount, uint256 _ethAmount) public lockAddingLiquidity payable{ //lockAddingLiquidity modifier
        //move amounts into contract
        _approve(msg.sender,address(this), _oilAmount);
        IERC20(address(this)).transferFrom(msg.sender, address(this), _oilAmount); 
        IERC20(uniswapV2Router.WETH()).transferFrom(msg.sender,address(this), _ethAmount);

        
        _approve(address(this),address(uniswapV2Router), _oilAmount);
        _approve(address(this),address(uniswapV2Router), _ethAmount);


        //this is if you desire to use ETH
        //(uint amountToken, uint amountETH, uint liquidity) =
        // uniswapV2Router.addLiquidityETH{value: msg.sender}(
        // address(this),
        // _oilAmount,
        // 0,
        // 0,
        // msg.sender,
        // block.timestamp +360
        // );

        // this is if you want to use WETH
        (uint oilAmount, uint _ethAmount, uint liquidity) =
        uniswapV2Router.addLiquidity(
        address(this),
        uniswapV2Router.WETH(),
        _oilAmount,
        _ethAmount,
        0,
        0, 
        msg.sender,
        block.timestamp +360
        );
    } 

    /*///////////////////////////////////////////////////////////////////
                            End of Tsuki Lab Addition
    ///////////////////////////////////////////////////////////////////*/

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

    function _getBonusPct() internal view returns (uint256 bonus) {
        uint256 balance = stakers[msg.sender].habibiz.length;

        if (balance < 5) return 0;
        if (balance < 10) return 15;
        if (balance < 20) return 25;
        return 35;
    }

    function _isAnimated(uint256 _id) internal pure returns (bool animated) {
        if (_id == 40) return true;
        if (_id == 108) return true;
        if (_id == 169) return true;
        if (_id == 191) return true;
        if (_id == 246) return true;
        if (_id == 257) return true;
        if (_id == 319) return true;
        if (_id == 386) return true;
        if (_id == 496) return true;
        if (_id == 562) return true;
        if (_id == 637) return true;
        if (_id == 692) return true;
        if (_id == 832) return true;
        if (_id == 942) return true;
        if (_id == 943) return true;
        if (_id == 957) return true;
        if (_id == 1100) return true;
        if (_id == 1108) return true;
        if (_id == 1169) return true;
        if (_id == 1178) return true;
        if (_id == 1627) return true;
        if (_id == 1706) return true;
        if (_id == 1843) return true;
        if (_id == 1884) return true;
        if (_id == 2137) return true;
        if (_id == 2158) return true;
        if (_id == 2165) return true;
        if (_id == 2214) return true;
        if (_id == 2232) return true;
        if (_id == 2238) return true;
        if (_id == 2508) return true;
        if (_id == 2629) return true;
        if (_id == 2863) return true;
        if (_id == 3055) return true;
        if (_id == 3073) return true;
        if (_id == 3280) return true;
        if (_id == 3297) return true;
        if (_id == 3322) return true;
        if (_id == 3327) return true;
        if (_id == 3361) return true;
        if (_id == 3411) return true;
        if (_id == 3605) return true;
        if (_id == 3639) return true;
        if (_id == 3774) return true;
        if (_id == 4250) return true;
        if (_id == 4267) return true;
        if (_id == 4302) return true;
        if (_id == 4362) return true;
        if (_id == 4382) return true;
        if (_id == 4397) return true;
        if (_id == 4675) return true;
        if (_id == 4707) return true;
        if (_id == 4863) return true;
        return false;
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
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}


interface IUniswapV2Router02 {
    function WETH() 
        external 
        pure 
        returns (
            address
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
        ) external;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
        ) external 
        payable 
        returns (
            uint amountToken, 
            uint amountETH, 
            uint liquidity
            );

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
        ) external returns (uint amountA, uint amountB, uint liquidity);
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
