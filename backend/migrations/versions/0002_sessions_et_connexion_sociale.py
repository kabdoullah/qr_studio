"""Connexion Google/Facebook et jetons de renouvellement.

- `users` : mot de passe et email facultatifs (comptes Google/Facebook),
  `avatar_url`, `email_verified` (faux pour les comptes existants : aucune
  adresse n'a encore été vérifiée).
- `auth_identities` : comptes externes rattachés à un utilisateur.
- `refresh_tokens` : empreintes des jetons de renouvellement, par session.

Aucune donnée existante n'est modifiée ni supprimée.

Revision ID: 0002
Revises: 0001
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = '0002'
down_revision: Union[str, None] = '0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('email', existing_type=sa.String(length=254), nullable=True)
        batch_op.alter_column('password_hash', existing_type=sa.String(length=255), nullable=True)
        batch_op.add_column(sa.Column('avatar_url', sa.String(length=500), nullable=True))
        batch_op.add_column(
            sa.Column('email_verified', sa.Boolean(), server_default=sa.false(), nullable=False)
        )

    op.create_table('auth_identities',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('provider', sa.String(length=20), nullable=False),
    sa.Column('provider_user_id', sa.String(length=255), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('provider', 'provider_user_id')
    )
    with op.batch_alter_table('auth_identities', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_auth_identities_user_id'), ['user_id'], unique=False)

    op.create_table('refresh_tokens',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('session_id', sa.Uuid(), nullable=False),
    sa.Column('token_hash', sa.String(length=64), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('replaced_by_token_id', sa.Uuid(), nullable=True),
    sa.Column('user_agent', sa.String(length=255), nullable=True),
    sa.Column('ip_address', sa.String(length=45), nullable=True),
    sa.ForeignKeyConstraint(['replaced_by_token_id'], ['refresh_tokens.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('token_hash')
    )
    with op.batch_alter_table('refresh_tokens', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_refresh_tokens_session_id'), ['session_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_refresh_tokens_user_id'), ['user_id'], unique=False)


def downgrade() -> None:
    with op.batch_alter_table('refresh_tokens', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_refresh_tokens_user_id'))
        batch_op.drop_index(batch_op.f('ix_refresh_tokens_session_id'))
    op.drop_table('refresh_tokens')
    with op.batch_alter_table('auth_identities', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_auth_identities_user_id'))
    op.drop_table('auth_identities')

    # Un compte Google/Facebook sans mot de passe ou sans email empêcherait
    # le retour en arrière : ils doivent être traités avant (refus explicite
    # plutôt que suppression silencieuse).
    connection = op.get_bind()
    blocking = connection.execute(
        sa.text('SELECT COUNT(*) FROM users WHERE password_hash IS NULL OR email IS NULL')
    ).scalar()
    if blocking:
        raise RuntimeError(
            f'{blocking} compte(s) sans mot de passe ou sans email : '
            'retour à 0001 impossible sans perte de données.'
        )
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('email_verified')
        batch_op.drop_column('avatar_url')
        batch_op.alter_column('password_hash', existing_type=sa.String(length=255), nullable=False)
        batch_op.alter_column('email', existing_type=sa.String(length=254), nullable=False)
