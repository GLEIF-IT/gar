Subject: Coordinating the delegated rotation

Hi all,

Here is how we will run the upcoming delegated rotation. The goal is that nobody approves anything they have not verified with the other side directly.

1. Schedule a call. All required QARs and at least the External GARs needed to meet our signing threshold join.

2. Rotate on your side. On the call, the QARs complete the multisig rotation and send the delegation request as usual. Do not wait for approval before sending it.

3. Read out the event. One QAR reads the following from the pending rotation event, and the others confirm it matches their view:
   - sequence number (s)
   - new signing keys (k) and threshold (kt)
   - new next-key digests (n) and threshold (nt)
   - any witness cuts or adds (br, ba)
   - the event SAID (d)

4. We compare. Each GAR pulls the pending rotation event from their local escrow and reads the same fields back. We check the added and removed keys against your current keys, the thresholds, and finally the SAID. A matching SAID means every other field matches, since it is the digest of the whole event.

5. We approve. Only once every GAR on the call has a match do we answer yes. The approval is an interaction event on the External AID carrying a seal of your event: identifier, sequence number, and SAID. Nothing else.

6. Fallback: manual anchor. If delegate confirm does not pick up the request, we do not retry blindly. We build the seal by hand from the three values we confirmed on the call and anchor it with a plain interaction event. The result is identical to step 5, so from your side there is no difference.

7. Confirm completion. You query our witnesses, see the anchor, and your rotation leaves escrow. Tell us on the call when your KEL shows the rotation as accepted, then we drop.

If anything does not match at step 4, we stop, nobody approves, and we work out why before trying again.

Thanks,
Kevin
