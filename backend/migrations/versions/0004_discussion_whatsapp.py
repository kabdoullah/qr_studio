"""Réseaux sociaux : mode discussion WhatsApp.

- `social_media_profiles.mode` : `page` pour toutes les pages existantes,
  qui continuent de fonctionner à l'identique.
- `social_media_profiles.message` : message prérempli (mode `whatsapp`).

Aucune donnée existante n'est modifiée ni supprimée.

Revision ID: 0004
Revises: 0003
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = '0004'
down_revision: Union[str, None] = '0003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('social_media_profiles', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('mode', sa.String(length=10), server_default='page', nullable=False)
        )
        batch_op.add_column(
            sa.Column('message', sa.String(length=300), server_default='', nullable=False)
        )


def downgrade() -> None:
    # Une discussion WhatsApp redeviendrait une page à un seul lien : son
    # message prérempli serait perdu. Refus explicite, comme pour 0003.
    connection = op.get_bind()
    blocking = connection.execute(
        sa.text("SELECT COUNT(*) FROM social_media_profiles WHERE mode <> 'page'")
    ).scalar()
    if blocking:
        raise RuntimeError(
            f'{blocking} discussion(s) WhatsApp : retour à 0003 impossible '
            'sans perte de données.'
        )
    with op.batch_alter_table('social_media_profiles', schema=None) as batch_op:
        batch_op.drop_column('message')
        batch_op.drop_column('mode')
