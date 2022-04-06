pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract Royals is ERC721A, Ownable {
    enum SaleState {
        Disabled,
        WhitelistSale,
        PublicSale
    }
    uint256 public totalSupplyLeft;
    uint256 public BatchSizeLeft;
    uint256 public maxMintPerWallet;
    uint256 public amountRequiredToBurn;
    bytes32 public root;
    string public baseURI;
    string public notRevealedUri;
    string public baseExtension = ".json";
    bool public revealed = false;
    IERC20Like public oil;
    IERC721Like public Habibiz;


    SaleState public saleState = SaleState.Disabled;

    event SaleStateChanged(uint256 previousState, uint256 nextState, uint256 timestamp);
    event FrozenHabibz(uint256[] frozenTokenIds);

    constructor(address _habibiz,address _oil, string memory _initBaseURI, string memory _initNotRevealedUri, uint256 _maxMintPerWallet) ERC721A("Royals", "ROYALS") {
    
        Habibiz = IERC721Like(_habibiz);
        totalSupplyLeft = 300; //the initial supply   
        oil = IERC20Like(_oil);
        BatchSizeLeft = 0;
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
        maxMintPerWallet = _maxMintPerWallet;
        _startTokenId();
        amountRequiredToBurn = 8;
    }

    modifier whenSaleIsActive() {
        require(saleState != SaleState.Disabled, "Sale is not active");
        _;
    }

        // Check if the whitelist is enabled and the address is part of the whitelist
    modifier isWhitelisted(
        address _address,
        bytes32[] calldata proof
    ) {
       
        require(
            saleState == SaleState.PublicSale || _verify(_leaf(_address), proof),
            "This address is not whitelisted"
        );
        _;
    }

    //++++++++
    // Public functions
    //++++++++

    // Use _getAux/setAux to be num of mints already occured 
    function mint(uint256[] calldata _habibizTokenId, bytes32[] calldata proof) external payable whenSaleIsActive isWhitelisted(msg.sender, proof) {
        require(_habibizTokenId.length >= amountRequiredToBurn, "You must burn atleast required amount of habibz");
        require(_habibizTokenId.length % amountRequiredToBurn == 0, "You must burn multiples of the required amount of habibz only");

        // Count number of potential mints 
        uint256 numToMint = _habibizTokenId.length / amountRequiredToBurn;
        bool duplicate = false;

        //ensure no duplicates are submitted

        // O(N^2) loop, its more gas efficient to use this than a mapping with addresses, due to lower storage usage
        for(uint256 i = 0; i < _habibizTokenId.length; i++) {
            for(uint256 j = i + 1; j < _habibizTokenId.length; j++) {
                if(_habibizTokenId[i] == _habibizTokenId[j]) {
                    duplicate = true;
                    break;
                }
            }
        }

        require(duplicate == false, "some of your inputs were not unique NFTs or some of these NFTs have already been burnt");
        // Now that we have amount a user can mint, lets ensure they can mint given maximum mints per wallet, and batch size
        require(numToMint <= BatchSizeLeft, "Theres none left in this batch to mint or you have requested a higher mint than whats alloted for this batch");
        require(numToMint <= totalSupplyLeft, "Theres no more Royals to mint or you have requested a higher mint than whats left in the supply");
        // Ensure user doesn't already exceed maximum number of mints
        require(_getAux(msg.sender) < maxMintPerWallet, "You do not have enough mints available");
        // Ensure user doesn't exceed maxmium allowable number of mints 
        require(uint256(_getAux(msg.sender)) + numToMint <= maxMintPerWallet, "Minting would exceed maximum allowable mints");
        // Burns staked habibis and if there was an issue burning, it reverts
        require(oil.burnHabibizForRoyals(msg.sender, _habibizTokenId), "There was an issue with the burns");
        
        BatchSizeLeft-= numToMint;
        totalSupplyLeft -= numToMint;
        _safeMint(msg.sender, numToMint);
        _setAux(_msgSender(), uint64(numToMint) + _getAux(msg.sender));
        emit FrozenHabibz(_habibizTokenId);

    }
    

    //++++++++
    // Owner functions
    //++++++++

    function setRoot(bytes32 _root) external onlyOwner {
        root = _root;
    }

    function reveal() public onlyOwner() {
        revealed = true;
    }

    // Sale functions
    function setSaleState(uint256 _state) external onlyOwner {
        uint256 prevState = uint256(saleState);
        saleState = SaleState(_state);
        emit SaleStateChanged(prevState, _state, block.timestamp);
    }

    function setBatchSize(uint256 size) external onlyOwner{
        require(
            totalSupplyLeft - size >= 0,
            "We have reached batch limit"
        );
        BatchSizeLeft = size;
    }

    function setMaxMintPerWallet(uint256 _maxMintPerWallet) public onlyOwner{
        maxMintPerWallet = _maxMintPerWallet;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }
    
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    function setOilAddress(address _oil) public onlyOwner {
        oil = IERC20Like(_oil);
    }


    //++++++++
    // Internal functions
    //++++++++
    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
    
    //++++++++
    // Override functions
    //++++++++
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory){
                
            require( _exists(tokenId),"ERC721Metadata: URI query for nonexistent token");

            if(revealed == false) {
                return notRevealedUri;
            }
        
            string memory currentBaseURI = _baseURI();
            return bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, Strings.toString(tokenId), baseExtension))
                : "";
    }


    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function walletOfOwner(address _owner) public virtual view returns (uint256[] memory) {
        uint256 _balance = balanceOf(_owner);
        uint256[] memory _tokens = new uint256[](_balance);
        uint _index;
        uint256 _loopThrough = totalSupply();
        for (uint256 i = 1; i< _loopThrough; i++){
            if(ownerOf(i) == _owner){
                _tokens[_index] = i;
                _index++;
            }
        }
        return _tokens;
    }

    /* ////////////////////////////////////////////////////////////////// DELETE LATER //////////////////////////////////////////////////////*/
    function getAux(address owner) public view returns (uint64) {
        return _getAux(owner);
    }

    function setTotalSupplyLeft(uint256 _amount) public {
        totalSupplyLeft = _amount;
    }

    function getFrozenHabibiz() public view returns(uint256[] memory){
        //habibiz.walletOfOwner(Oil address )
        //only issue is this will return staked NFTs as well

    }
    function setAux(address owner, uint64 aux) public {
        _setAux(owner, aux);
    }


}





interface IERC721Like {
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

interface IERC20Like{

    function burnHabibizForRoyals(address user,uint256[] calldata _tokenIds) external returns (bool);
}






