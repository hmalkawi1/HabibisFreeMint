pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";


// interface IERC721Enumerable is ERC721A {
//     /**
//      * @dev Returns the total amount of tokens stored by the contract.
//      */
//     function totalSupply() external view returns (uint256);

//     /**
//      * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
//      * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
//      */
//     function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

//     /**
//      * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
//      * Use along with {totalSupply} to enumerate all tokens.
//      */
//     function tokenByIndex(uint256 index) external view returns (uint256);
// }

contract Royals is ERC721A, Ownable {
    enum SaleState {
        Disabled,
        WhitelistSale,
        PublicSale
    }

    uint256 public totalSupplyLeft;
    uint256 public BatchSizeLeft;
    uint256 public maxMintPerWallet;
    bytes32 public root;
    string public baseURI;
    string public notRevealedUri;
    string public baseExtension = ".json";
    IERC20Like public oil;
    ERC721Like public Habibiz;

    uint256[] public frozenHabibiz;
    mapping(uint => bool) private exists;


    SaleState public saleState = SaleState.Disabled;

    event SaleStateChanged(uint256 previousState, uint256 nextState, uint256 timestamp);

    constructor(address _habibiz,address _oil, string memory _initBaseURI, string memory _initNotRevealedUri, uint256 _maxMintPerWallet) ERC721A("Royals", "ROYLS") {
    
        Habibiz = ERC721Like(_habibiz);
        totalSupplyLeft = 300; //the initial supply   
        oil = IERC20Like(_oil);
        BatchSizeLeft = 0;
        setBaseURI(_initBaseURI);
        setNotRevealedURI(_initNotRevealedUri);
        maxMintPerWallet = _maxMintPerWallet;
        _startTokenId();
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
        require(_habibizTokenId.length >= 8, "You must burn atleast 8 habibz");
        require(_habibizTokenId.length % 8 == 0, "You must burn multiples of 8 habibz only");

        // Count number of potential mints 
        uint256 numToMint = 0;
        //ensure no duplicates are submitted
        
        for (uint256 k = 0; k < _habibizTokenId.length; k++){
            require(exists[_habibizTokenId[k]] == false, "Atleast one of your submitted habibz is not unique");
            if ( k % 8 == 0) {
                numToMint +=1;
            }
    
            exists[_habibizTokenId[k]] = true;
           
            frozenHabibiz.push(_habibizTokenId[k]);
        }
        // Now that we have amount a user can mint, lets ensure they can mint given maximum mints per wallet, and batch size
        require(numToMint <= BatchSizeLeft, "Theres none left in this batch to mint or you have requested a higher mint than whats alloted for this batch");
        require(numToMint <= totalSupplyLeft, "Theres no more Royals to mint");
        // Ensure user doesn't already exceed maximum number of mints
        require(_getAux(msg.sender) < maxMintPerWallet, "You do not have enough mints available");
        // Ensure user doesn't exceed maxmium allowable number of mints 
        require(uint256(_getAux(msg.sender)) + numToMint <= maxMintPerWallet, "Minting would exceed maximum allowable mints");
        // Burns staked habibis and if there was an issue burning, it reverts
        require(oil.burnHabibizForRoyals(msg.sender, _habibizTokenId), "There was an issue with the burns");
        
        
        BatchSizeLeft-= numToMint;
        totalSupplyLeft -= numToMint;
        _safeMint(msg.sender, numToMint);
        numToMint += _getAux(msg.sender);
        _setAux(_msgSender(), uint64(numToMint) + _getAux(msg.sender));
    }


    
    //++++++++
    // Owner functions
    //++++++++

    function setRoot(bytes32 _root) external onlyOwner {
        root = _root;
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
        
            string memory currentBaseURI = _baseURI();
            return bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, Strings.toString(tokenId), baseExtension))
                : "";
    }
    /**
     * To change the starting tokenId, please override this function.
     */
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
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



    /* DELETE LATER */
    function setTotalSupplyLeft(uint256 _amount) public {
        totalSupplyLeft = _amount;
    }

    function getFrozenHabibiz() public view returns(uint256[] memory){
        return frozenHabibiz;
    }
    function setAux(address owner, uint64 aux) public {
        _setAux(owner, aux);
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

interface IERC20Like{

    function burnHabibizForRoyals(address user,uint256[] calldata _tokenIds) external returns (bool);
}



/*/
//override tokenstart to start from 1


/*
Project requirements:

- Batches (decided by team) -done 
- 300 max NFT supply - done
- Whitelist - done
- 8 Habibiz for 1 royal NFT mint - done



//Think this is done in the OIL contract side ://

-Staking is time locked (30,60,90) 
    -30 days: 15%
    -60 days: 30%
    -90 days: 100%

- staking 1 royal = 12000 OIL per day
- staking 2 royals = 13500 OIL PER ROYAL per day
- staking 3 royals = 15000 OIL PER ROYAL Per Day
*/


