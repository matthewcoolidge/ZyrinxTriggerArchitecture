/**
 * @description Trigger Action to reparent Voice Call records when an Account is deleted/merged
 */
public with sharing class AccountTriggerActionAfterDeleteVoice implements ZyrinxTriggerArchitecture.executeMethod {
    /**
    * @description ZyrinxTriggerArchitecture.executeMethod
    * @param List<SObject> records
    * @param Map<Id,SObject> oldMap
    * @param ZyrinxTriggerArchitecture.triggerParameters tp
    */
    public void execute(List<SObject> records, Map<Id, SObject> oldMap, ZyrinxTriggerArchitecture.triggerParameters tp) {
        Set<Id> deletedAccountIds = Pluck.ids(Account.Id, oldMap.values());
        List<VoiceCall> voiceCalls = [SELECT Id, RelatedRecordId, Account__c FROM VoiceCall WHERE RelatedRecordId IN :deletedAccountIds];
        Map<Id, List<VoiceCall>> voiceCallsByRelatedRecordId = (Map<Id, List<VoiceCall>>)GroupBy.ids(VoiceCall.RelatedRecordId, voiceCalls);
        List<VoiceCall> voiceCallsToUpdate = new List<VoiceCall>();
        for(Account acc : (List<Account>)oldMap.values()) {
            for(VoiceCall accVoiceCall : voiceCallsByRelatedRecordId.get(acc.Id)) {
                if(accVoiceCall.RelatedRecordId != accVoiceCall.Account__c) {
                    accVoiceCall.RelatedRecordId = accVoiceCall.Account__c;
                    voiceCallsToUpdate.add(accVoiceCall);
                }
            }
        }
        if(!voiceCallsToUpdate.isEmpty()) {
            update voiceCallsToUpdate;
        }
    }
}