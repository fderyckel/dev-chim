"use client";

import { useEffect, useState } from "react";

import {
  defaultExperienceProfileId,
  experienceProfiles,
  type ExperienceProfileId,
} from "../generated/profiles";
import { ActionButton } from "./actions";
import { StatusBadge } from "./status-badge";

function applyPreviewProfile(profileId: ExperienceProfileId) {
  const root = document.documentElement;
  root.dataset.themeChanging = "true";

  if (profileId === defaultExperienceProfileId) {
    delete root.dataset.theme;
  } else {
    root.dataset.theme = profileId;
  }

  void root.offsetWidth;
  delete root.dataset.themeChanging;
}

export function ExperienceProfilePreview() {
  const [profileId, setProfileId] = useState<ExperienceProfileId>(
    defaultExperienceProfileId,
  );
  const selectedProfile =
    experienceProfiles.find((profile) => profile.id === profileId) ??
    experienceProfiles[0];

  useEffect(() => {
    applyPreviewProfile(profileId);

    return () => {
      delete document.documentElement.dataset.theme;
      delete document.documentElement.dataset.themeChanging;
    };
  }, [profileId]);

  if (!selectedProfile) {
    return null;
  }

  return (
    <div className="c-profile-preview">
      <fieldset className="c-profile-picker">
        <legend className="c-profile-picker__legend">Choose a preview profile</legend>
        <p className="c-profile-picker__guidance" id="profile-preview-guidance">
          Each choice changes the complete page so hierarchy, controls, and status
          meaning can be judged together.
        </p>

        <div
          className="c-profile-picker__options"
          aria-describedby="profile-preview-guidance"
        >
          {experienceProfiles.map((profile) => (
            <label className="c-profile-option" key={profile.id}>
              <input
                className="c-profile-option__input u-visually-hidden"
                type="radio"
                name="experience-profile"
                value={profile.id}
                checked={profile.id === profileId}
                onChange={() => setProfileId(profile.id)}
              />
              <span className="c-profile-option__indicator" aria-hidden="true" />
              <span className="c-profile-option__copy">
                <strong className="c-profile-option__label">{profile.label}</strong>
                <span className="c-profile-option__description">
                  {profile.description}
                </span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>

      <div className="c-profile-preview__result" role="status" aria-live="polite">
        <div className="c-profile-preview__summary">
          <StatusBadge tone="positive">Preview active</StatusBadge>
          <p>
            <strong className="c-profile-preview__name">{selectedProfile.label}</strong>{" "}
            is shown locally. It is not saved.
          </p>
        </div>
        <ActionButton
          variant="secondary"
          disabled={profileId === defaultExperienceProfileId}
          onClick={() => setProfileId(defaultExperienceProfileId)}
        >
          Reset to Chimwemwe default
        </ActionButton>
      </div>

      <div className="c-profile-preview__tones" aria-label="Status meaning preview">
        <StatusBadge>Neutral</StatusBadge>
        <StatusBadge tone="information">Information</StatusBadge>
        <StatusBadge tone="positive">Ready</StatusBadge>
        <StatusBadge tone="attention">Needs attention</StatusBadge>
        <StatusBadge tone="critical">Critical</StatusBadge>
      </div>

      <p className="c-profile-preview__boundary">
        Preview only: reload or leave this page to return to Quiet light. No browser or
        server storage is used.
      </p>
    </div>
  );
}
