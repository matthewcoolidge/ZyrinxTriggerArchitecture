trigger AccountTrigger on Account (before insert, before update, before delete, after insert, after update, after delete) {

    // Ability to totally block - useful in tests where the Custom Setting may be unavailable
    // This should allow the TKWWTA and Legacy architctures to exist side by side with no code changes
    if(Label.TriggerBlockTKWWTA == 'true' && !Test.isRunningTest()){
        System.debug('TriggerBlockTKWWTA, skipping AccountTrigger');
    }
    else{
        TKWWTriggerArchitecture.executeAllMethods();
    }
}