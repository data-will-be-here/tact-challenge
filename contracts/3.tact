import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  If smart contract pool doesn't have enough jettons to trade
  (for example someone sends 99999 jettons of B, but dex pool only has 10 of jettons A),
  then sent incoming jettons (B, in our example) back to the sender.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task3 with Deployable {
  owner: Address;
  a: Int;
  b: Int;
  jA: Address;
  jB: Address;
  decimal: Int;

  init(admin: Address, newJA: Address, newJB: Address) {
    self.owner = admin;
    self.jA = newJA; // wallet address
    self.jB = newJB; // wallet address
    self.a = 0; // 10
    self.b = 0; // 2
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
    let jettonAddress: Address = sender();
    require(jettonAddress == self.jA || jettonAddress == self.jB, "not an paired jetton");
    self.swap(msg.from, msg.amount, jettonAddress);
  } 

  fun swap(from: Address, amount: Int, jettonAddress: Address): Int {
      if(from == self.owner) {
      if(jettonAddress == self.jA) { self.a = self.a + amount; }
        else { self.b = self.b + amount; }
        send(SendParameters{
          to: from,
          value: 0, 
          mode: SendRemainingValue + SendIgnoreErrors,
          bounce: true
      });
      return 1;
    } else {
      let to_recv: Int = (self.b * self.decimal / self.a) * amount / self.decimal;
      let dest: Address = self.jB;
      if(jettonAddress == self.jA) { // send B tokens, plus A tokens
        if(self.b < to_recv || to_recv == 0) {
          dest = self.jA;
          to_recv = amount;
        } else {
          self.a = self.a + amount;
          self.b = self.b - to_recv;
        }
          return self.sendTokens(dest, to_recv, from);
      } else {
        to_recv = (self.a * self.decimal / self.b) * amount / self.decimal;
        if(self.a < to_recv || to_recv == 0) {
          to_recv = amount;
        } else {
          dest = self.jA;
          self.b = self.b + amount;
          self.a = self.a - to_recv;
        }
          return self.sendTokens(dest, to_recv, from);
      }
    }
  }

  fun sendTokens(to: Address, to_recv: Int, dest: Address): Int {
        send(SendParameters{
            to: to,
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            bounce: true, 
            body: TokenTransfer {
                queryId: 0,
                amount: to_recv,
                destination: dest,
                responseDestination: myAddress(),
                customPayload: null,
                forwardTonAmount: ton("0.01"),
                forwardPayload: emptySlice()
            }.toCell()
            });
            return 1;
  }

  get fun price(token: Address): Int { 
    if(token == self.jB) {
      return self.a * self.decimal / self.b; // amountOfJettonAOnContract * decimal / amountOfJettonBOnContract 10 * 1000000000 / 2 = 5000000000
    } 
      return self.b * self.decimal / self.a; //
  }
  
  get fun balance(token: Address): Int { 
    if(token == self.jA) {
      return self.a;
    }
      return self.b;
  }
}
