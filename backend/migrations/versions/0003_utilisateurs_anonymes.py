"""Utilisateurs anonymes (anonymous-first).

- `users.is_anonymous` : faux pour tous les comptes existants, qui
  continuent de fonctionner à l'identique.
- `users.installation_hash` : empreinte de l'identifiant d'installation
  d'un compte anonyme (unique).
- `users.first_name` / `last_name` facultatifs : un compte anonyme n'a pas
  de nom.

Aucune donnée existante n'est modifiée ni supprimée.

Revision ID: 0003
Revises: 0002
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = '0003'
down_revision: Union[str, None] = '0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('is_anonymous', sa.Boolean(), server_default=sa.false(), nullable=False)
        )
        batch_op.add_column(sa.Column('installation_hash', sa.String(length=64), nullable=True))
        batch_op.create_unique_constraint('uq_users_installation_hash', ['installation_hash'])
        batch_op.alter_column('first_name', existing_type=sa.String(length=100), nullable=True)
        batch_op.alter_column('last_name', existing_type=sa.String(length=100), nullable=True)


def downgrade() -> None:
    # Supprimer silencieusement les comptes anonymes effacerait leurs QR
    # Codes : ils doivent être traités avant (refus explicite).
    connection = op.get_bind()
    blocking = connection.execute(
        sa.text('SELECT COUNT(*) FROM users WHERE is_anonymous')
    ).scalar()
    if blocking:
        raise RuntimeError(
            f'{blocking} compte(s) anonyme(s) : retour à 0002 impossible '
            'sans perte de données.'
        )
    connection.execute(sa.text("UPDATE users SET first_name = '' WHERE first_name IS NULL"))
    connection.execute(sa.text("UPDATE users SET last_name = '' WHERE last_name IS NULL"))
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('last_name', existing_type=sa.String(length=100), nullable=False)
        batch_op.alter_column('first_name', existing_type=sa.String(length=100), nullable=False)
        batch_op.drop_constraint('uq_users_installation_hash', type_='unique')
        batch_op.drop_column('installation_hash')
        batch_op.drop_column('is_anonymous')
