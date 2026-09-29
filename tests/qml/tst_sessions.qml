import QtQuick
import QtTest
import "../../components"

TestCase {
  name: "SessionLifecycle"
  when: windowShown

  Component { id: meetingComponent; MeetingPresentation {} }
  Component { id: dictationComponent; DictationSession {} }

  function newMeeting() {
    const model = createTemporaryObject(meetingComponent, this)
    verify(model !== null)
    model.meetingId = "meeting-1"
    model.meetingState = "recording"
    model.recorderHealth = "recording"
    model.elapsedText = "02:15"
    tryCompare(model, "displayState", "recording")
    return model
  }

  function test_meetingPauseFinish() {
    const model = newMeeting()
    model.meetingState = "paused"
    tryCompare(model, "displayState", "pausing")
    model.recorderHealth = "paused"
    tryCompare(model, "displayState", "paused")
    model.stopping = true
    model.elapsedText = "00:00"
    model.recorderHealth = "finishing"
    tryCompare(model, "displayState", "finishing")
    compare(model.shownElapsedText, "02:15")
    model.meetingState = "idle"
    model.recorderHealth = "done"
    tryCompare(model, "displayState", "finished")
    tryCompare(model, "presented", false, 2000)
  }

  function test_errorDoesNotLeakIntoNextMeeting() {
    const model = newMeeting()
    model.recorderHadError = true
    tryCompare(model, "hadAudioError", true)
    model.meetingState = "idle"
    model.recorderHealth = "done"
    tryCompare(model, "displayState", "failed")
    // Deliberately change identity last, as can happen with QML bindings.
    model.meetingState = "recording"
    model.recorderHealth = "recording"
    model.recorderHadError = false
    model.meetingId = "meeting-2"
    tryCompare(model, "displayState", "recording")
    compare(model.hadAudioError, false)
    model.meetingState = "idle"
    model.recorderHealth = "done"
    tryCompare(model, "displayState", "finished")
  }

  function test_newMeetingCancelsOldHideTimer() {
    const model = newMeeting()
    model.meetingState = "idle"
    model.recorderHealth = "done"
    tryCompare(model, "displayState", "finished")
    model.meetingId = "meeting-2"
    model.meetingState = "recording"
    model.recorderHealth = "recording"
    tryCompare(model, "displayState", "recording")
    wait(1200)
    verify(model.presented)
    compare(model.reveal, 1)
  }

  function test_cancelDuringEntranceAndQuickRestart() {
    const session = createTemporaryObject(dictationComponent, this)
    session.showState("recording")
    wait(20)
    session.showState("idle")
    tryCompare(session, "panelMapped", false)
    compare(session.reveal, 0)
    session.showState("recording")
    session.showState("transcribing")
    session.showState("idle")
    wait(20)
    session.showState("recording")
    wait(250)
    verify(session.panelMapped)
    compare(session.displayState, "recording")
    compare(session.reveal, 1)
  }

  function test_invalidAudioDoesNotPoisonNextFrames() {
    const session = createTemporaryObject(dictationComponent, this)
    session.showState("recording")
    session.updateAudio(NaN, Infinity)
    session.updateAudio(0.5, 0.2)
    wait(60)
    session.updateAudio(0.5, 0.2)
    verify(Number.isFinite(session.smoothedEnergy))
    verify(session.smoothedEnergy > session.baseLevel)
  }

  function test_lostAudioSettlesInsteadOfFreezing() {
    const session = createTemporaryObject(dictationComponent, this)
    session.showState("recording")
    for (let i = 0; i < 6; i++) session.previewAudio(0.8, 0.4)
    verify(session.smoothedEnergy > 0.8)
    tryVerify(function() { return session.smoothedEnergy < 0.2 }, 1600)
    session.showState("idle")
  }
}
