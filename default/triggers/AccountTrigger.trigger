trigger AccountTrigger on Account (before insert, before update, before delete, after insert, after update, after delete) {

    // Ability to totally block - useful in tests where the Custom Setting may be unavailable
    // This should allow the Zyrinx and Legacy architctures to exist side by side with no code changes
    if(Label.TriggerBlockZyrinx == 'true' && !Test.isRunningTest()){
        System.debug('TriggerBlockZyrinx, skipping AccountTrigger');
    }
    else{
        ZyrinxTriggerArchitecture.executeAllMethods();
    }
}