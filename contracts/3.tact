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
  jAddressA: Address;
  jAddressB: Address;
  decimal: Int;

  init(admin: Address, newJAddressA: Address, newJAddressB: Address) {
    self.owner = admin;
    self.jAddressA = newJAddressA;
    self.jAddressB = newJAddressB;
    self.a = 0; // 10
    self.b = 0; // 2
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
    let jettonAddress: Address = sender();
    require(jettonAddress == self.jAddressA || jettonAddress == self.jAddressB, "not an paired jetton");
    let sender: Address = msg.from;
    let amount: Int = msg.amount;
    let jettonA: Bool = false;
    if(jettonAddress == self.jAddressA) { jettonA = true; }
    if(sender == self.owner) {
      if(jettonA) { self.a = self.a + amount; }
      else { self.b = self.b + amount; }
      send(SendParameters{
        to: sender,
        value: 0, 
        mode: SendIgnoreErrors + SendRemainingValue, 
        bounce: true
    });
    } else {
      let to_recv: Int = 0;
      let dest: Address = jettonAddress;
      if(jettonA) { // send B tokens, plus A tokens
      to_recv = (self.b * self.decimal / self.a) * amount / self.decimal; // (2 * 1000000000 / 10) * 5 / 1000000000
      dest = self.jAddressB;
        if(self.b < to_recv) {
          dest = self.jAddressA;
          to_recv = amount;
        } else {
          self.a = self.a + amount;
          self.b = self.b - to_recv;
        }
      } else {
      to_recv = (self.a * self.decimal / self.b) * amount / self.decimal; // (10 * 1000000000 / 2) * 1 / 1000000000 = 5
      dest = self.jAddressA;
        if(self.a < to_recv) {
          dest = self.jAddressB;
          to_recv = amount;
        } else {
          self.b = self.b + amount;
          self.a = self.a - to_recv;
        }
      }
      
        send(SendParameters{
            to: dest,
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            bounce: true, 
            body: TokenTransfer {
                queryId: msg.queryId,
                amount: to_recv,
                destination: sender,
                responseDestination: sender,
                customPayload: null,
                forwardTonAmount: 0,
                forwardPayload: msg.forwardPayload
            }.toCell()
            }
        );
    }
  } 
  
  get fun price(token: Address): Int { 
    if(token == self.jAddressA) {
      return self.a * self.decimal / self.b; // amountOfJettonAOnContract * decimal / amountOfJettonBOnContract 10 * 1000000000 / 2 = 5000000000
    } else if(token == self.jAddressB) {
      return self.b * self.decimal / self.a; //
    } else {
      return 0;
    }
  }
  
  get fun balance(token: Address): Int { 
    if(token == self.jAddressA) {
      return self.a;
    } else if(token == self.jAddressB) { 
      return self.b;
    } else {
      return 0;
    } 
  }
}
