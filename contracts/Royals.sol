pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "./abstract/Withdrawable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";



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
    ERC721Like Habibiz;

    mapping(address => uint256) mintAllowance;
    IERC20 oil;
    //getaux setaux() <16 then mint 1, if <32 min 2


    SaleState public saleState = SaleState.Disabled;

    event SaleStateChanged(uint256 previousState, uint256 nextState, uint256 timestamp);

    constructor(address _habibiz,address _oil) ERC721A("Royals", "ROYLS") {
    
        Habibiz = ERC721Like(_habibiz);
        totalSupplyLeft = 300; //the initial supply   
        oil = IERC20(_oil);
        BatchSizeLeft = 0;
    }

    modifier whenSaleIsActive() {
        require(saleState != SaleState.Disabled, "Sale is not active");
        _;
    }

        // Check if the whitelist is enabled and the address is part of the whitelist
    modifier isWhitelisted(
        address _address,
        uint256 amount,
        bytes32[] calldata proof
    ) {
        require(
            saleState == SaleState.WhitelistSale || _verify(_leaf(_address), proof),
            "This address is not whitelisted or has reached maximum mints"
        );
        _;
    }

    //++++++++
    // Public functions
    //++++++++

    // Payable mint function for unrevealed NFTs
    function mint(uint256 amount, bytes32[] calldata proof) external payable whenSaleIsActive isWhitelisted(msg.sender, amount, proof) {
        require(BatchSizeLeft>0, "Theres none left in this batch to mint");
        //require(mintAllowance[msg.sender]> 0, "You have no mints left");
        //require(amount <= mintAllowance[msg.sender], "You do not have enough mints allowed");
        
        uint64 numMints = _getAux(msg.sender) - uint64(amount);
        require(numMints <= maxMintPerWallet, "This value is greater than what you're allowed to mint");

        //case of user inputs amount> batchsizeleft and hes allowed for more
        if(amount> BatchSizeLeft && BatchSizeLeft>0 && amount+BatchSizeLeft <= 300){
            mintAllowance[msg.sender] -= BatchSizeLeft;     
            BatchSizeLeft = 0;
            totalSupplyLeft -= BatchSizeLeft;
            _safeMint(msg.sender, BatchSizeLeft);
            _setAux(_msgSender(), _getAux(msg.sender) - uint64(BatchSizeLeft)); 
        }

        require(amount <= totalSupplyLeft, "Minting would exceed cap");
    
        mintAllowance[msg.sender] -= amount;     
        BatchSizeLeft-= amount;
        totalSupplyLeft -= amount;
        _safeMint(msg.sender, amount);
        _setAux(_msgSender(), _getAux(msg.sender) - uint64(amount)); 
    }

    //Burns 8 at a time
    function burn(uint256[] calldata _habibiz) external {
        require(_habibiz.length == 8, "You must burn exactly 8 a time");
        uint256 burntHabibiCounts = 0;
        for (uint256 i = 0; i < _habibiz.length; i++) {
            require(Habibiz.ownerOf(_habibiz[i]) == msg.sender, "At least one Habibi is not owned by you.");
            burntHabibiCounts +=1;    
        }
            //freeze all 8 at once
            //freeze(_habibiz);

        if(burntHabibiCounts % 8 == 0){
            _setAux(msg.sender, _getAux(msg.sender) + 1);
        }
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
        oil = IERC20(_oil);
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

    //function freeze(address msg.sender,uint256 _habibiz[i]) internal {
        //must call OIL contract to freeze habibi and remove owner
        //in the oil contract, must renounce ownership of _habibiz[i]

        //Habibiz.ownerOf(_habibiz[i]) = address(oil);


    //}


    //
    // function habibizOfStaker(address _staker) public view returns (uint256[] memory) {
    //     uint256[] memory tokenIds = new uint256[](stakers[_staker].habibiz.length);
    //     for (uint256 i = 0; i < stakers[_staker].habibiz.length; i++) {
    //         tokenIds[i] = stakers[_staker].habibiz[i].tokenId;
    //     }
    //     return tokenIds;
    // }

    
    //++++++++
    // Override functions
    //++++++++
    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    

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


     /**
     * Returns the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    // function _getAux(address owner) internal view returns (uint64) {
    //     return _addressData[owner].aux;
    // }

    /**
     * Sets the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    // function _setAux(address owner, uint64 aux) internal {
    //     _addressData[owner].aux = aux;
    // }

    /* Example for reveal
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        if (bytes(baseURI).length > 0) {
            return string(abi.encodePacked(abi.encodePacked(baseURI, tokenId.toString()), ".json"));
        } else {
            if (tokenId % 2 == 0) {
                return bytes(unrevealedURIs[0]).length != 0 ? unrevealedURIs[0] : "";
            } else {
                return bytes(unrevealedURIs[1]).length != 0 ? unrevealedURIs[1] : "";
            }
        }
    }
    
    
    */


    //nice to haves:
    // function walletOfOwner(address _owner) 
    //     public
    //     view
    //     returns (
    //         uint256[] memory){
        
    //     uint256 ownerTokenCount = balanceOf(_owner);
    //     uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    //     for (uint256 i; i < ownerTokenCount; i++) {
    //     tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    //     }
    //     return tokenIds;
    // }

    // function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
    //     require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
    //     return _ownedTokens[owner][index];
    // }

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



/*/
Some questions:

1- Do we want to just hardcode whitelist in contract and just have a setter function that can add to it? or merkletrees? - Keep merkle
2- What do you want us to do with burns? just burn it or transfer to one of your wallets ? - Freeze(), remove owner from oil contract sice they're staked
3- Are we doing 1 mint at a time, or should they mint multiples ? - limit mints per wallet
4- Will they all be revealed right away? or will they mint unrevealed
/*/

//getAux setAux(uint) erc721, sets number minted for tokenOwner
//override tokenstart to start from 1


/*
Project requirements:

- Batches (decided by team)
- 300 max NFT supply
- Whitelist 
- 8 Habibiz for 1 royal NFT mint



//Think this is done in the OIL contract side ://

-Staking is time locked (30,60,90) 
    -30 days: 15%
    -60 days: 30%
    -90 days: 100%

- staking 1 royal = 12000 OIL per day
- staking 2 royals = 13500 OIL PER ROYAL per day
- staking 3 royals = 15000 OIL PER ROYAL Per Day
*/


