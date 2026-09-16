import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.book import Book
from app.models.club import (
    BookClub,
    ClubBingoCard,
    ClubBingoSquare,
    ClubBook,
    ClubMemberBingoCard,
    ClubMemberBingoSquare,
    ClubMembership,
    ClubMembershipStatus,
    ClubNote,
    ClubReadingProgress,
    ClubRole,
)
from app.models.user import User
from app.routers.bingo import DEFAULT_LABELS
from app.schemas.club import (
    ClubBingoLeaderboardEntryOut,
    ClubBingoOut,
    ClubBingoSquareUpdate,
    ClubBingoTemplateCreate,
    ClubBookCreate,
    ClubBookDatesUpdate,
    ClubBookOut,
    ClubCreate,
    ClubInviteCreate,
    ClubInviteOut,
    ClubInviteRespond,
    ClubMemberBingoSquareOut,
    ClubMemberOut,
    ClubMemberUpdate,
    ClubNoteCreate,
    ClubNoteOut,
    ClubOut,
    ClubOwnershipTransfer,
    ClubProgressUpdate,
    ClubReviewEntryOut,
    ClubUpdate,
)
from app.schemas.pagination import Page, PageParams

router = APIRouter(prefix="/clubs", tags=["clubs"])

FREE_SPACE_POSITION = 12


def _get_club_or_404(club_id: uuid.UUID, db: Session) -> BookClub:
    club = db.get(BookClub, club_id)
    if club is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Book club not found")
    return club


def _get_membership(club_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> ClubMembership | None:
    return (
        db.query(ClubMembership)
        .filter(ClubMembership.club_id == club_id, ClubMembership.user_id == user_id)
        .first()
    )


def _require_membership(
    club_id: uuid.UUID, user: User, db: Session, roles: set[ClubRole] | None = None
) -> ClubMembership:
    membership = _get_membership(club_id, user.id, db)
    if membership is None or membership.status != ClubMembershipStatus.active:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not a member of this club")
    if roles is not None and membership.role not in roles:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "You don't have permission to do this")
    return membership


def _current_book(club_id: uuid.UUID, db: Session) -> ClubBook | None:
    return db.query(ClubBook).filter(ClubBook.club_id == club_id, ClubBook.is_current.is_(True)).first()


def _build_club_out(club: BookClub, viewer_role: ClubRole, db: Session) -> ClubOut:
    memberships = db.query(ClubMembership).filter(ClubMembership.club_id == club.id).all()
    book = _current_book(club.id, db)
    progress_by_user: dict[uuid.UUID, ClubReadingProgress] = {}
    if book is not None:
        rows = db.query(ClubReadingProgress).filter(ClubReadingProgress.club_book_id == book.id).all()
        progress_by_user = {row.user_id: row for row in rows}

    members = []
    for membership in memberships:
        progress = progress_by_user.get(membership.user_id)
        members.append(
            ClubMemberOut(
                user_id=membership.user_id,
                name=membership.user.name,
                email=membership.user.email,
                avatar_url=membership.user.avatar_url,
                role=membership.role,
                status=membership.status,
                current_chapter=progress.current_chapter if progress else None,
                finished=progress.finished if progress else None,
            )
        )

    return ClubOut(
        id=club.id,
        name=club.name,
        description=club.description,
        owner_id=club.owner_id,
        my_role=viewer_role,
        created_at=club.created_at,
        members=members,
        current_book=ClubBookOut.model_validate(book) if book else None,
    )


@router.post("", response_model=ClubOut, status_code=status.HTTP_201_CREATED)
def create_club(payload: ClubCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    club = BookClub(owner_id=current_user.id, name=payload.name, description=payload.description)
    db.add(club)
    db.flush()

    db.add(
        ClubMembership(
            club_id=club.id,
            user_id=current_user.id,
            role=ClubRole.owner,
            status=ClubMembershipStatus.active,
            joined_at=datetime.now(timezone.utc),
        )
    )
    db.commit()
    db.refresh(club)
    return _build_club_out(club, ClubRole.owner, db)


@router.get("", response_model=Page[ClubOut])
def list_my_clubs(
    page: PageParams = Depends(), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    base_query = db.query(ClubMembership).filter(
        ClubMembership.user_id == current_user.id, ClubMembership.status == ClubMembershipStatus.active
    )
    total = base_query.count()
    memberships = base_query.order_by(ClubMembership.joined_at.desc()).limit(page.limit).offset(page.offset).all()
    items = [_build_club_out(db.get(BookClub, m.club_id), m.role, db) for m in memberships]
    return Page(items=items, total=total, limit=page.limit, offset=page.offset)


@router.get("/invites", response_model=list[ClubInviteOut])
def list_my_invites(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    memberships = (
        db.query(ClubMembership)
        .filter(ClubMembership.user_id == current_user.id, ClubMembership.status == ClubMembershipStatus.invited)
        .all()
    )
    out = []
    for membership in memberships:
        club = db.get(BookClub, membership.club_id)
        inviter = db.get(User, membership.invited_by_id) if membership.invited_by_id else None
        out.append(
            ClubInviteOut(
                club_id=club.id,
                club_name=club.name,
                invited_by_name=inviter.name if inviter else "Someone",
                invited_at=membership.invited_at,
            )
        )
    return out


@router.get("/{club_id}", response_model=ClubOut)
def get_club(club_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    club = _get_club_or_404(club_id, db)
    membership = _require_membership(club_id, current_user, db)
    return _build_club_out(club, membership.role, db)


@router.patch("/{club_id}", response_model=ClubOut)
def update_club(
    club_id: uuid.UUID, payload: ClubUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    club = _get_club_or_404(club_id, db)
    membership = _require_membership(club_id, current_user, db, roles={ClubRole.owner, ClubRole.admin})

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(club, field, value)

    db.commit()
    db.refresh(club)
    return _build_club_out(club, membership.role, db)


@router.delete("/{club_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_club(club_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    club = _get_club_or_404(club_id, db)
    if club.owner_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the club owner can delete this club")

    db.delete(club)
    db.commit()


@router.post("/{club_id}/transfer-ownership", response_model=ClubOut)
def transfer_ownership(
    club_id: uuid.UUID,
    payload: ClubOwnershipTransfer,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    club = _get_club_or_404(club_id, db)
    if club.owner_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the club owner can transfer ownership")

    if payload.new_owner_id == current_user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You're already the owner")

    new_owner_membership = _get_membership(club_id, payload.new_owner_id, db)
    if new_owner_membership is None or new_owner_membership.status != ClubMembershipStatus.active:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That person isn't an active member of this club")

    current_owner_membership = _get_membership(club_id, current_user.id, db)

    club.owner_id = payload.new_owner_id
    new_owner_membership.role = ClubRole.owner
    if current_owner_membership is not None:
        current_owner_membership.role = ClubRole.admin

    db.commit()
    db.refresh(club)
    return _build_club_out(club, ClubRole.admin, db)


@router.post("/{club_id}/invites", response_model=ClubMemberOut, status_code=status.HTTP_201_CREATED)
def invite_member(
    club_id: uuid.UUID,
    payload: ClubInviteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db, roles={ClubRole.owner, ClubRole.admin})

    invitee = db.query(User).filter(User.email == payload.email).first()
    if invitee is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No Bookmarked user found with that email")

    membership = _get_membership(club_id, invitee.id, db)
    if membership is not None:
        if membership.status == ClubMembershipStatus.active:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "That person is already in the club")
        membership.status = ClubMembershipStatus.invited
        membership.invited_by_id = current_user.id
        membership.invited_at = datetime.now(timezone.utc)
    else:
        membership = ClubMembership(
            club_id=club_id,
            user_id=invitee.id,
            role=ClubRole.member,
            status=ClubMembershipStatus.invited,
            invited_by_id=current_user.id,
        )
        db.add(membership)

    db.commit()
    return ClubMemberOut(
        user_id=invitee.id,
        name=invitee.name,
        email=invitee.email,
        avatar_url=invitee.avatar_url,
        role=membership.role,
        status=membership.status,
    )


@router.post("/{club_id}/invites/respond", response_model=ClubOut)
def respond_to_invite(
    club_id: uuid.UUID,
    payload: ClubInviteRespond,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    club = _get_club_or_404(club_id, db)
    membership = _get_membership(club_id, current_user.id, db)
    if membership is None or membership.status != ClubMembershipStatus.invited:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No pending invite for this club")

    if payload.accept:
        membership.status = ClubMembershipStatus.active
        membership.joined_at = datetime.now(timezone.utc)
    else:
        membership.status = ClubMembershipStatus.declined

    db.commit()
    return _build_club_out(club, membership.role, db)


@router.post("/{club_id}/leave", status_code=status.HTTP_204_NO_CONTENT)
def leave_club(club_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _get_club_or_404(club_id, db)
    membership = _require_membership(club_id, current_user, db)
    if membership.role == ClubRole.owner:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "The owner can't leave the club — delete it or hand off ownership first",
        )
    membership.status = ClubMembershipStatus.removed
    db.commit()


@router.patch("/{club_id}/members/{user_id}", response_model=ClubOut)
def update_member(
    club_id: uuid.UUID,
    user_id: uuid.UUID,
    payload: ClubMemberUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    club = _get_club_or_404(club_id, db)
    viewer_membership = _require_membership(club_id, current_user, db, roles={ClubRole.owner, ClubRole.admin})

    target = _get_membership(club_id, user_id, db)
    if target is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Member not found")
    if target.role == ClubRole.owner:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The club owner can't be modified")

    if payload.remove:
        target.status = ClubMembershipStatus.removed
    elif payload.role is not None:
        if payload.role == ClubRole.owner:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Use POST /clubs/{club_id}/transfer-ownership to transfer ownership")
        target.role = payload.role

    db.commit()
    return _build_club_out(club, viewer_membership.role, db)


@router.post("/{club_id}/book", response_model=ClubBookOut)
def set_current_book(
    club_id: uuid.UUID,
    payload: ClubBookCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db, roles={ClubRole.owner, ClubRole.admin})

    db.query(ClubBook).filter(ClubBook.club_id == club_id, ClubBook.is_current.is_(True)).update(
        {"is_current": False}, synchronize_session=False
    )

    book = ClubBook(
        club_id=club_id,
        title=payload.title,
        author=payload.author,
        total_chapters=payload.total_chapters,
        cover_color=payload.cover_color,
        cover_url=payload.cover_url,
        is_current=True,
        start_date=payload.start_date,
        end_date=payload.end_date,
    )
    db.add(book)
    db.flush()

    active_members = (
        db.query(ClubMembership)
        .filter(ClubMembership.club_id == club_id, ClubMembership.status == ClubMembershipStatus.active)
        .all()
    )
    for membership in active_members:
        db.add(ClubReadingProgress(club_book_id=book.id, user_id=membership.user_id))

    db.commit()
    db.refresh(book)
    return book


@router.patch("/{club_id}/book", response_model=ClubBookOut)
def update_current_book_dates(
    club_id: uuid.UUID,
    payload: ClubBookDatesUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db, roles={ClubRole.owner, ClubRole.admin})

    book = _current_book(club_id, db)
    if book is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This club hasn't picked a book yet")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(book, field, value)

    db.commit()
    db.refresh(book)
    return book


@router.get("/{club_id}/books", response_model=Page[ClubBookOut])
def list_club_books(
    club_id: uuid.UUID,
    page: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db)
    base_query = db.query(ClubBook).filter(ClubBook.club_id == club_id)
    total = base_query.count()
    items = base_query.order_by(ClubBook.picked_at.desc()).limit(page.limit).offset(page.offset).all()
    return Page(items=items, total=total, limit=page.limit, offset=page.offset)


def _resolve_club_book(club_id: uuid.UUID, club_book_id: uuid.UUID | None, db: Session) -> ClubBook | None:
    if club_book_id is not None:
        book = db.query(ClubBook).filter(ClubBook.id == club_book_id, ClubBook.club_id == club_id).first()
        if book is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Book not found in this club")
        return book
    return _current_book(club_id, db)


@router.patch("/{club_id}/progress", response_model=ClubMemberOut)
def update_progress(
    club_id: uuid.UUID,
    payload: ClubProgressUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    membership = _require_membership(club_id, current_user, db)

    book = _current_book(club_id, db)
    if book is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This club hasn't picked a book yet")

    progress = (
        db.query(ClubReadingProgress)
        .filter(ClubReadingProgress.club_book_id == book.id, ClubReadingProgress.user_id == current_user.id)
        .first()
    )
    if progress is None:
        progress = ClubReadingProgress(club_book_id=book.id, user_id=current_user.id)
        db.add(progress)
        db.flush()

    if payload.current_chapter is not None:
        progress.current_chapter = payload.current_chapter
    if payload.finished is not None:
        progress.finished = payload.finished
        progress.finished_at = datetime.now(timezone.utc) if payload.finished else None

    db.commit()
    return ClubMemberOut(
        user_id=current_user.id,
        name=current_user.name,
        email=current_user.email,
        avatar_url=current_user.avatar_url,
        role=membership.role,
        status=membership.status,
        current_chapter=progress.current_chapter,
        finished=progress.finished,
    )


@router.get("/{club_id}/notes", response_model=Page[ClubNoteOut])
def list_notes(
    club_id: uuid.UUID,
    chapter: int | None = None,
    club_book_id: uuid.UUID | None = None,
    page: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db)

    book = _resolve_club_book(club_id, club_book_id, db)
    if book is None:
        return Page(items=[], total=0, limit=page.limit, offset=page.offset)

    my_progress = (
        db.query(ClubReadingProgress)
        .filter(ClubReadingProgress.club_book_id == book.id, ClubReadingProgress.user_id == current_user.id)
        .first()
    )
    my_chapter = my_progress.current_chapter if my_progress else 0

    query = db.query(ClubNote).filter(ClubNote.club_book_id == book.id)
    if chapter is not None:
        query = query.filter(ClubNote.chapter == chapter)

    notes = query.order_by(ClubNote.chapter, ClubNote.created_at).all()
    # Spoiler visibility is per-row application logic, not a column, so it
    # has to be filtered in Python before paginating (pushing limit/offset
    # to the DB query would paginate the wrong, unfiltered set).
    visible = [note for note in notes if note.user_id == current_user.id or note.chapter <= my_chapter]
    page_slice = visible[page.offset : page.offset + page.limit]

    return Page(
        items=[
            ClubNoteOut(
                id=note.id,
                chapter=note.chapter,
                body=note.body,
                user_id=note.user_id,
                author_name=note.user.name,
                created_at=note.created_at,
                updated_at=note.updated_at,
            )
            for note in page_slice
        ],
        total=len(visible),
        limit=page.limit,
        offset=page.offset,
    )


@router.post("/{club_id}/notes", response_model=ClubNoteOut, status_code=status.HTTP_201_CREATED)
def add_note(
    club_id: uuid.UUID,
    payload: ClubNoteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db)

    book = _current_book(club_id, db)
    if book is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This club hasn't picked a book yet")

    my_progress = (
        db.query(ClubReadingProgress)
        .filter(ClubReadingProgress.club_book_id == book.id, ClubReadingProgress.user_id == current_user.id)
        .first()
    )
    my_chapter = my_progress.current_chapter if my_progress else 0
    if payload.chapter > my_chapter:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can't leave a note for a chapter you haven't reached yet")

    note = ClubNote(club_book_id=book.id, user_id=current_user.id, chapter=payload.chapter, body=payload.body)
    db.add(note)
    db.commit()
    db.refresh(note)
    return ClubNoteOut(
        id=note.id,
        chapter=note.chapter,
        body=note.body,
        user_id=note.user_id,
        author_name=current_user.name,
        created_at=note.created_at,
        updated_at=note.updated_at,
    )


@router.get("/{club_id}/reviews", response_model=Page[ClubReviewEntryOut])
def list_reviews(
    club_id: uuid.UUID,
    override: bool = False,
    club_book_id: uuid.UUID | None = None,
    page: PageParams = Depends(),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db)

    book = _resolve_club_book(club_id, club_book_id, db)
    if book is None:
        return Page(items=[], total=0, limit=page.limit, offset=page.offset)

    my_progress = (
        db.query(ClubReadingProgress)
        .filter(ClubReadingProgress.club_book_id == book.id, ClubReadingProgress.user_id == current_user.id)
        .first()
    )
    viewer_finished = bool(my_progress and my_progress.finished)

    active_members = (
        db.query(ClubMembership)
        .filter(ClubMembership.club_id == club_id, ClubMembership.status == ClubMembershipStatus.active)
        .all()
    )

    out: list[ClubReviewEntryOut] = []
    for membership in active_members:
        is_own = membership.user_id == current_user.id
        review_book = (
            db.query(Book)
            .filter(
                Book.user_id == membership.user_id,
                func.lower(Book.title) == book.title.lower(),
                func.lower(Book.author) == book.author.lower(),
            )
            .first()
        )
        has_review = review_book is not None and any(
            [
                review_book.rating is not None,
                bool(review_book.final_review),
                bool(review_book.liked_most),
                bool(review_book.liked_least),
                bool(review_book.feel),
            ]
        )

        if not has_review:
            # Nothing to show for someone else; for the viewer's own row, still
            # surface it so the app can offer to add/review this book.
            if not is_own:
                continue
            out.append(
                ClubReviewEntryOut(
                    user_id=membership.user_id,
                    name=membership.user.name,
                    finished=False,
                    locked=False,
                    book_id=None,
                )
            )
            continue

        # A viewer never needs a spoiler warning for their own review.
        locked = not is_own and not viewer_finished and not override
        if locked:
            out.append(
                ClubReviewEntryOut(
                    user_id=membership.user_id,
                    name=membership.user.name,
                    finished=review_book.read,
                    locked=True,
                    spoiler_warning="You haven't finished this book yet. Viewing may spoil it for you.",
                )
            )
            continue

        out.append(
            ClubReviewEntryOut(
                user_id=membership.user_id,
                name=membership.user.name,
                finished=review_book.read,
                locked=False,
                book_id=review_book.id if is_own else None,
                rating=review_book.rating,
                rating_cover=review_book.rating_cover,
                rating_writing=review_book.rating_writing,
                rating_plot=review_book.rating_plot,
                rating_characters=review_book.rating_characters,
                enjoyed=review_book.enjoyed,
                read_again=review_book.read_again,
                liked_most=review_book.liked_most,
                liked_least=review_book.liked_least,
                feel=review_book.feel,
                trope=review_book.trope,
                final_review=review_book.final_review,
                favorite_characters=review_book.favorite_characters,
                notable_scenes=review_book.notable_scenes,
                quotes=review_book.quotes,
            )
        )

    page_slice = out[page.offset : page.offset + page.limit]
    return Page(items=page_slice, total=len(out), limit=page.limit, offset=page.offset)


def _get_or_create_member_bingo(club_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> ClubBingoOut:
    template = db.query(ClubBingoCard).filter(ClubBingoCard.club_id == club_id).first()
    if template is None:
        template = ClubBingoCard(club_id=club_id)
        db.add(template)
        db.flush()
        labels = list(DEFAULT_LABELS)
        labels[FREE_SPACE_POSITION] = "FREE SPACE"
        for position, label in enumerate(labels):
            db.add(ClubBingoSquare(card_id=template.id, position=position, label=label))
        db.commit()

    member_card = (
        db.query(ClubMemberBingoCard)
        .filter(ClubMemberBingoCard.club_id == club_id, ClubMemberBingoCard.user_id == user_id)
        .first()
    )
    if member_card is None:
        member_card = ClubMemberBingoCard(club_id=club_id, user_id=user_id)
        db.add(member_card)
        db.flush()
        for square in template.squares:
            is_free = square.position == FREE_SPACE_POSITION
            db.add(
                ClubMemberBingoSquare(
                    card_id=member_card.id,
                    position=square.position,
                    label=square.label,
                    completed=is_free,
                    locked=is_free,
                )
            )
        db.commit()
        db.refresh(member_card)

    return _build_bingo_out(club_id, member_card, db)


def _build_bingo_out(club_id: uuid.UUID, member_card: ClubMemberBingoCard, db: Session) -> ClubBingoOut:
    active_members = (
        db.query(ClubMembership)
        .filter(ClubMembership.club_id == club_id, ClubMembership.status == ClubMembershipStatus.active)
        .all()
    )

    leaderboard = []
    for membership in active_members:
        card = (
            db.query(ClubMemberBingoCard)
            .filter(ClubMemberBingoCard.club_id == club_id, ClubMemberBingoCard.user_id == membership.user_id)
            .first()
        )
        if card is None:
            continue
        completed = sum(1 for sq in card.squares if sq.completed)
        leaderboard.append(
            ClubBingoLeaderboardEntryOut(
                user_id=membership.user_id,
                name=membership.user.name,
                completed_count=completed,
                total_count=len(card.squares),
                won_at=card.won_at,
            )
        )

    leaderboard.sort(key=lambda e: (-e.completed_count, e.won_at or datetime.max.replace(tzinfo=timezone.utc)))

    return ClubBingoOut(
        squares=[ClubMemberBingoSquareOut.model_validate(sq) for sq in member_card.squares],
        leaderboard=leaderboard,
    )


@router.post("/{club_id}/bingo/template", response_model=ClubBingoOut)
def set_bingo_template(
    club_id: uuid.UUID,
    payload: ClubBingoTemplateCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db, roles={ClubRole.owner, ClubRole.admin})

    existing = db.query(ClubBingoCard).filter(ClubBingoCard.club_id == club_id).first()
    if existing is not None:
        db.delete(existing)
    db.query(ClubMemberBingoCard).filter(ClubMemberBingoCard.club_id == club_id).delete(synchronize_session=False)
    db.flush()

    card = ClubBingoCard(club_id=club_id)
    db.add(card)
    db.flush()

    labels = list(payload.labels)
    labels[FREE_SPACE_POSITION] = "FREE SPACE"
    for position, label in enumerate(labels):
        db.add(ClubBingoSquare(card_id=card.id, position=position, label=label))

    db.commit()
    return _get_or_create_member_bingo(club_id, current_user.id, db)


@router.get("/{club_id}/bingo", response_model=ClubBingoOut)
def get_bingo(club_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db)
    return _get_or_create_member_bingo(club_id, current_user.id, db)


@router.patch("/{club_id}/bingo/squares/{square_id}", response_model=ClubBingoOut)
def toggle_bingo_square(
    club_id: uuid.UUID,
    square_id: uuid.UUID,
    payload: ClubBingoSquareUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_club_or_404(club_id, db)
    _require_membership(club_id, current_user, db)

    square = db.get(ClubMemberBingoSquare, square_id)
    if square is None or square.card.club_id != club_id or square.card.user_id != current_user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Bingo square not found")
    if square.locked:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This square can't be edited")

    square.completed = payload.completed
    db.flush()

    member_card = square.card
    if all(sq.completed for sq in member_card.squares):
        if member_card.won_at is None:
            member_card.won_at = datetime.now(timezone.utc)
    else:
        member_card.won_at = None

    db.commit()
    return _build_bingo_out(club_id, member_card, db)
