// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract FreeMint is ERC721A, Ownable {
    //StakerSale = sale for stakers of Royals/Habibi NFTs
    //WhitelistSale = sale for non stakers who are whitelisted
    //AllSale = sale for stakers AND open to purchase for everyone else (no need for WL here)
    //PublicSale = sale open for everyone
    enum SaleState {
        Disabled,
        StakerSale,
        WhitelistSale,
        PublicSale
    }

    SaleState public saleState = SaleState.Disabled;

    uint256 public price = 49000000000000000;
    uint256 public totalSupplyLeft_Stakers = 4000;
    uint256 public totalSupplyLeft_Sale = 2000;
    uint256 public maxSaleMintPerWallet = 1;
    bytes32 public root;


    string public baseURI;
    string public baseExtension = ".json";
    IERC20Like public OIL; //SET HERE HARD CODED WITH MAINNET VALUE
    

    event SaleStateChanged(uint256 prevState,uint256 nextState, uint256 timeStamp);
    event Mint(address minter, uint256 amount);

    constructor(string memory baseURI_, address oil) ERC721A("FreeMint", "FRMNT") {
        baseURI = baseURI_;
        OIL = IERC20Like(oil);
    }

    modifier whenStakerSaleIsActive() {
        require(saleState == SaleState.StakerSale, "Staker Sale is not active");
        _;
    }

    modifier whenSaleIsActive() {
        require(saleState == SaleState.WhitelistSale || saleState == SaleState.PublicSale, "Sale is not active");
        _;
    }
    
    modifier isInAllowlist(address address_, bytes32[] calldata proof_) {
        require( saleState == SaleState.PublicSale || _verify(_leaf(address_), proof_), "Not in allowlist");
        _;
    }

    function mintForStaker(uint256 amount) external whenStakerSaleIsActive {
        (uint256[] memory stakedHabibiz, uint256[] memory stakedRoyals) = OIL.allStakedOfStaker(msg.sender);
        //uint256 maxMintAmount = stakedHabibiz.length + stakedRoyals.length - claimedPerAddress[msg.sender];
        uint256 maxMintAmount = stakedHabibiz.length + stakedRoyals.length - _getAux(msg.sender);
        require(amount + _getAux(msg.sender) <= maxMintAmount && amount <= totalSupplyLeft_Stakers, "Minting would exceed your free mint Limits or supply limit");
        
        totalSupplyLeft_Stakers -= amount;
        _setAux(msg.sender, _getAux(msg.sender) + uint64(amount));
        _safeMint(msg.sender, amount);
        emit Mint(msg.sender, amount);

    }

    function mintForSale(uint256 amount,  bytes32[] calldata proof_) external payable whenSaleIsActive isInAllowlist(msg.sender, proof_){
        require(amount + _getAux(msg.sender) <= maxSaleMintPerWallet && amount + _getAux(msg.sender) <= totalSupplyLeft_Sale, "Minting would exceed your mint Limits or supply limit");
        require(price * amount <= msg.value, "Value sent is not correct");
        
        totalSupplyLeft_Sale -= amount;
        _setAux(msg.sender, _getAux(msg.sender) + uint64(amount)); 
        _safeMint(msg.sender, amount);
        emit Mint(msg.sender, amount);
    }


    /*////////////////////////////////
                Owner Only
    ///////////////////////////////*/

    function setTotalSupplyLeft(uint256 _stakerAmount, uint256 _saleAmount) public onlyOwner{
        totalSupplyLeft_Stakers = _stakerAmount;
        totalSupplyLeft_Sale = _saleAmount;
    }

    function setRoot(bytes32 root_) external onlyOwner {
        root = root_;
    }

    function setPrice(uint256 _price) public onlyOwner{
        price = _price;
    }

    function setSaleState(uint256 _state) external onlyOwner {
        uint256 prevState = uint256(saleState);
        saleState = SaleState(_state);
        emit SaleStateChanged(prevState, _state, block.timestamp);
    }
    
    function setSaleMaxMintPerWallet(uint256 _maxMintPerWallet) public onlyOwner{
        maxSaleMintPerWallet = _maxMintPerWallet;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function withdraw() public payable onlyOwner {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    /*////////////////////////////////
                Overrides
    ///////////////////////////////*/

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory){
                
            require( _exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
        
            string memory currentBaseURI = _baseURI();
            return bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, Strings.toString(tokenId), baseExtension))
                : "";
    }

    //++++++++
    // Internal functions
    //++++++++
    function _leaf(address account_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account_));
    }

    function _verify(bytes32 leaf_, bytes32[] memory proof_) internal view returns (bool) {
        return MerkleProof.verify(proof_, root, leaf_);
    }

    function walletOfOwner(address _owner) public virtual view returns (uint256[] memory) {
        uint256 _balance = balanceOf(_owner);
        uint256[] memory _tokens = new uint256[](_balance);
        uint _index;
        uint256 _loopThrough = totalSupply();
        for (uint256 i = 1; i<= _loopThrough; i++){
            if(ownerOf(i) == _owner){
                _tokens[_index] = i;
                _index++;
            }
        }

        return _tokens;
    }



}

interface IERC20Like{

    function allStakedOfStaker(address _staker) view external returns (uint256[] memory, uint256[] memory);
}