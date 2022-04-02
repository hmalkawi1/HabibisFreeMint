pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "./abstract/Withdrawable.sol";
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

contract Royals is ERC721A, Ownable, Withdrawable {
    enum SaleState {
        Disabled,
        WhitelistSale
    }

    uint256 public totalSupplyLeft;
    uint256 public BatchSizeLeft;
    uint256 public maxMintPerWallet;
    bytes32 public root;
    string public baseURI;
    string public baseExtension = ".json";
    IERC20Like public oil;
    ERC721Like public Habibiz;

    mapping(address => uint256) mintAllowance;


    SaleState public saleState = SaleState.Disabled;

    event SaleStateChanged(uint256 previousState, uint256 nextState, uint256 timestamp);

    constructor(address _habibiz,address _oil) ERC721A("Royals", "ROYLS") {
    
        Habibiz = ERC721Like(_habibiz);
        totalSupplyLeft = 300; //the initial supply   
        oil = IERC20Like(_oil);
        BatchSizeLeft = 0;
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
            saleState == SaleState.WhitelistSale || _verify(_leaf(_address), proof),
            "This address is not whitelisted or has reached maximum mints"
        );
        console.logAddress(_address);
        _;
    }

    //++++++++
    // Public functions
    //++++++++

    // Payable mint function for unrevealed NFTs
    // function mint(uint256 amount, bytes32[] calldata proof) external payable whenSaleIsActive isWhitelisted(msg.sender, proof) {
    //     require(BatchSizeLeft > 0, "Theres none left in this batch to mint");
    //     require(amount > 0, "You must enter a valid amount ");
    //     require(_getAux(msg.sender) - uint64(amount) > 0, "This value is greater than what you're allowed to mint");
        


    //     /* Case of user inputs amount > batchsizeleft and he's able to mint more
    //         I.e  when BatchSizeLeft = 2 but amount = 3, instead of reverting, just mint 2 as long as its less than total supply
    //     */
    //     // (amount + BatchSizeLeft) -> this should only be BatchSizeLeft, since we're taking the minimum of the two 
    //     if( amount > BatchSizeLeft && BatchSizeLeft > 0 && BatchSizeLeft <= totalSupplyLeft){
    //         amount = BatchSizeLeft;
    //     }
        
    //     require(amount <= totalSupplyLeft, "Minting would exceed cap");

    //     BatchSizeLeft-= amount;
    //     totalSupplyLeft -= amount;
    //     _safeMint(msg.sender, amount);
    //     _setAux(_msgSender(), _getAux(msg.sender) - uint64(amount));
    // }

    function mint(bytes32[] calldata proof) external payable whenSaleIsActive isWhitelisted(msg.sender, proof) {
        require(BatchSizeLeft > 0, "Theres none left in this batch to mint");
        require(_getAux(msg.sender) > 0, "You do not have enough mints available");
        

        //require(_getAux(msg.sender) <= totalSupplyLeft, "Minting would exceed cap");

        BatchSizeLeft-= _getAux(msg.sender);
        totalSupplyLeft -= _getAux(msg.sender);
        _safeMint(msg.sender, _getAux(msg.sender));
        _setAux(_msgSender(), uint64(0));
    }

    //Burns 8 at a time
    //what if totalsupplyLeft =1, and 2 people call a burn ?
    function burn(uint256[] calldata _habibiz) public {
        require(totalSupplyLeft>0, "Theres no more Royals to mint");
        require(_habibiz.length == 8, "You must burn exactly 8 a time");

        uint256 burntHabibiCounts = 0;
        for (uint256 i = 0; i < _habibiz.length; i++) {
            require(Habibiz.ownerOf(_habibiz[i]) == msg.sender, "At least one Habibi is not owned by you.");
            burntHabibiCounts +=1;    
        }

        require(oil.burnHabibizForRoyals(msg.sender, _habibiz), "There was an issue with the burns");
        
        _setAux(msg.sender, _getAux(msg.sender) + 1);

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
    function getAux(address owner) public view returns (uint64) {
        return _getAux(owner);
    }

    /**
     * Sets the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
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


