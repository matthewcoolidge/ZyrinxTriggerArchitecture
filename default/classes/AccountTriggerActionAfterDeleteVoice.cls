/**
 * @description Trigger Action to reparent Voice Call records when an Account is deleted/merged
 *               https://theknotww.atlassian.net/browse/QTC-7835
 * @author Charlie Faber
 * @date 2023-11-6
 */
public with sharing class AccountTriggerActionAfterDeleteVoice implements TKWWTriggerArchitecture.executeMethod {
    /**
    * @description TKWWTriggerArchitecture.executeMethod
    * @param List<SObject> records
    * @param Map<Id,SObject> oldMap
    * @param TKWWTriggerArchitecture.triggerParameters tp
    */
    public void execute(List<SObject> records, Map<Id, SObject> oldMap, TKWWTriggerArchitecture.triggerParameters tp) {
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