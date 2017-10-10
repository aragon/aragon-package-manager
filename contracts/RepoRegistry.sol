pragma solidity ^0.4.11;

import "./AbstractENS.sol";
import "./Ownable.sol";
import "./Repo.sol";
import "./ForwarderFactory.sol";

contract RepoRegistry is AddrResolver, Ownable {
    AbstractENS ens;
    bytes32 public rootNode;
    mapping (bytes32 => address) public registeredRepos;

    ForwarderFactory private repoFactory;

    event NewRepo(bytes32 id, string name, address repo);

    /**
    * @dev In order to function correctly, Registry must be set as the owner of the rootNode record in the ENS
    * @param _ens Reference to the ENS Registry
    * @param _rootNode ENS namehash where the registry is running. Example: namehash("aragonpm.eth")
    * @param _repoFactory Forwarder factory instance that deploys forwarders to Repo contracts
    */
    function RepoRegistry(AbstractENS _ens, bytes32 _rootNode, ForwarderFactory _repoFactory) {
        rootNode = _rootNode;
        ens = _ens;
        repoFactory = _repoFactory;
    }

    /**
    * @notice Create new repo in registry with `_name`
    * @param _name Repo name
    */
    function newRepo(string _name) public returns (address) {
        bytes32 label = sha3(_name);
        bytes32 node = sha3(rootNode, label);
        require(registeredRepos[node] == 0);

        Repo repo = newClonedRepo();
        registeredRepos[node] = address(repo);

        // Creates [name] subdomain in the rootNode and sets registry as resolver
        ens.setSubnodeOwner(rootNode, label, address(this));
        ens.setResolver(node, address(this));
        repo.transferOwnership(msg.sender);

        NewRepo(node, _name, repo);

        return address(repo);
    }

    /**
    * @dev After receiving ownership of rootnode, this can be called to set contract as
    *      resolver for rootnode, resulting in rootnode resolving to the RepoRegistry address
    */
    function setResolver() public {
        ens.setResolver(rootNode, address(this));
    }

    /**
    * @dev Transfers rootNode ownership (used for migrating to another Registry)
    *      After changing ownership of name, RepoRegistry will fail to create new records
    */
    function setRootOwner(address _newOwner) public onlyOwner {
        ens.setOwner(rootNode, _newOwner);
    }

    /**
    * @dev Conformance to ENS AddrResolver
    * @param node ENS namehash for name
    */
    function addr(bytes32 node) constant returns (address) {
        // Resolve to RepoRegistry if asked for root node, otherwise return repo address if exists
        return node == rootNode ? address(this) : registeredRepos[node];
    }

    function newClonedRepo() internal returns (Repo) {
        return Repo(repoFactory.createForwarder());
    }
}
