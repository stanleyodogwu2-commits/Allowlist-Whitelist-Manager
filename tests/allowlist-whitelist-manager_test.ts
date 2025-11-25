import { Clarinet, Tx, Chain, Account, types } from "clarinet";

Clarinet.test({
  name: "owner can create and update phases",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;

    let block = chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "create-phase",
        [
          types.uint(1),
          types.ascii("presale"),
          types.uint(0),
          types.uint(1000),
          types.uint(2),
          types.uint(1000000)
        ],
        deployer.address
      )
    ]);

    block.receipts[0].result.expectOk();

    block = chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "update-phase",
        [
          types.uint(1),
          types.uint(10),
          types.uint(1000),
          types.uint(3),
          types.uint(2000000)
        ],
        deployer.address
      )
    ]);

    block.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "owner can manage allowlist entries",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "create-phase",
        [
          types.uint(1),
          types.ascii("presale"),
          types.uint(0),
          types.uint(1000),
          types.uint(2),
          types.uint(1000000)
        ],
        deployer.address
      )
    ]);

    let block = chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "add-to-allowlist",
        [types.uint(1), types.principal(wallet1.address)],
        deployer.address
      ),
    ]);

    block.receipts[0].result.expectOk();

    block = chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "remove-from-allowlist",
        [types.uint(1), types.principal(wallet1.address)],
        deployer.address
      ),
    ]);

    block.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "can-mint? enforces phase activity and per-address limits",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;

    // phase active from block 1 to 100
    chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "create-phase",
        [
          types.uint(1),
          types.ascii("presale"),
          types.uint(1),
          types.uint(100),
          types.uint(2),
          types.uint(1000000)
        ],
        deployer.address
      )
    ]);

    chain.mineEmptyBlock(1);

    chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "add-to-allowlist",
        [types.uint(1), types.principal(wallet1.address)],
        deployer.address
      )
    ]);

    let block = chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "check-and-consume",
        [types.uint(1), types.principal(wallet1.address), types.uint(1)],
        wallet1.address
      ),
    ]);

    block.receipts[0].result.expectOk();

    block = chain.mineBlock([
      Tx.contractCall(
        "allowlist-whitelist-manager",
        "check-and-consume",
        [types.uint(1), types.principal(wallet1.address), types.uint(2)],
        wallet1.address
      ),
    ]);

    block.receipts[0].result.expectErr().expectUint(105);
  },
});
