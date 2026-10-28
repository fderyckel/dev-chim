defmodule Chimwemwe.Classroom.ReviewFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias Chimwemwe.Classroom.{Fixture, Foundation}
  alias Chimwemwe.People.Foundation, as: People

  def staff_classrooms!(f) do
    first =
      classroom!(
        f,
        "Oak daily register",
        ["Alex Rivera", "Bo Linden", "Casey Vale", "Dara Moss"],
        true
      )

    classroom!(f, "Aspen daily register", ["Eli Brook", "Fara Lake", "Gabi Reed", "Hari Stone"])
    first
  end

  def classroom!(f, label, names, reuse_student? \\ false) do
    assert {:ok, class} =
             Foundation.create_class(
               f.persistence,
               Fixture.context_a(),
               Map.put(Fixture.class_input(f), :label, label)
             )

    assert {:ok, assignment} =
             Foundation.assign_teacher(
               f.persistence,
               Fixture.context_a(),
               Fixture.teacher_input(f, class)
             )

    placements =
      for {name, index} <- Enum.with_index(names) do
        student =
          if reuse_student? and index == 0 do
            assert {:ok, participation} =
                     People.current_participation(f.runtime, Fixture.context_a(), f.student.id)

            assert {:ok, person} =
                     People.current_person(
                       f.runtime,
                       Fixture.context_a(),
                       participation.person_id
                     )

            assert {:ok, _} =
                     People.revise_person_name(
                       f.runtime,
                       Fixture.context_a(),
                       Map.merge(Fixture.keys(), %{
                         person_id: person.id,
                         expected_version: person.lock_version,
                         display_name: name,
                         reason: :name_correction
                       })
                     )

            f.student
          else
            assert {:ok, person} =
                     People.register_person(
                       f.runtime,
                       Fixture.context_a(),
                       Map.put(Fixture.keys(), :display_name, name)
                     )

            Fixture.participation!(f, person, :student)
          end

        enrolment = Fixture.enrolment!(%{f | student: student})

        assert {:ok, placement} =
                 Foundation.place_student(
                   f.persistence,
                   Fixture.context_a(),
                   Fixture.placement_input(enrolment, class)
                 )

        {enrolment, placement}
      end

    [{enrolment, placement} | _] = placements
    {class, enrolment, assignment, placement}
  end
end
