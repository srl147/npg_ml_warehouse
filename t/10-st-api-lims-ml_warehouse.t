use strict;
use warnings;
use Test::More tests => 98;
use Test::Exception;
use Test::Deep;
use Moose::Meta::Class;

use_ok('st::api::lims::ml_warehouse');

my $schema_wh;
lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_stlims_wh]) 
} 'ml_warehouse test db created';

{
  throws_ok {st::api::lims::ml_warehouse->new(
    mlwh_schema => $schema_wh)->query_resultset}
    qr/Either id_flowcell_lims or flowcell_barcode should be defined/,
    'error when no flowcell attributes are given';

  my $rs;
  throws_ok {$rs = st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => 'barcode')->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse flowcell_barcode barcode/,
    'error when non-existing barcode is given';

  throws_ok {$rs = st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => 'XX_99_XX')->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse id_flowcell_lims XX_99_XX/,
    'error when non-existing flowcell id is given';

  throws_ok {
    $rs = st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => '42UMBAAXX',
      id_flowcell_lims => 'XX_99_XX')->query_resultset
  }
qr/No record retrieved for st::api::lims::ml_warehouse flowcell_barcode 42UMBAAXX, id_flowcell_lims XX_99_XX/,
  'error retrieving data with valid barcode and invalid flowcell id';

  ok (st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => '42UMBAAXX')->query_resultset->count,
   'data retrieved for existing barcode');
  ok (st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => 4775)->query_resultset->count,
    'data retrieved for existing flowcell id supplied as an integer');
  ok (st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775')->query_resultset->count,
    'data retrieved for existing flowcell id supplied as a string');
  ok (st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => 22043,
      flowcell_barcode => 'barcode')->query_resultset->count,
    'data retrieved as long as flowcell id is valid');

  throws_ok { st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043,
                                 position         => 2)->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse id_flowcell_lims 22043, position 2/,
    'error when lane does not exist';

  ok (st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043,
                                 position         => 1)->query_resultset->count,
    'data retrieved for existing lane');
  throws_ok { st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043,
                                 position         => 1,
                                 tag_index        => 326)->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse id_flowcell_lims 22043, position 1, tag_index 326/,
    'error when tag index does not exist';
}

{
  my $d = st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775');
  isa_ok ($d, 'st::api::lims::ml_warehouse');
  my @children = $d->children;
  my %types;
  my @positions = ();
  map { $types{ref $_} = 1; push @positions, $_->position} @children;
  is (join(q[,], keys %types), 'st::api::lims::ml_warehouse', 'children have correct class');
  is (join(q[,], @positions), '1,2,3,4,5,6,7,8', 'eight children sorted by position');
  ok (!$d->is_control, 'not control');
  ok (!$d->is_pool, 'not pool');
  ok (!$d->study_name, 'no study name');
  ok (!$d->sample_id, 'no sample_id');

  my $lims1 = $children[0];
  ok (!$lims1->is_control, 'first lane is not control');
  ok (!$lims1->is_pool, 'first lane is not a pool');
  ok (!$lims1->children, 'children list is empty');
  cmp_ok($lims1->library_id, q(eq), 'PD3918a 1', 'lib id');
  cmp_ok($lims1->library_name, q(eq), 'PD3918a 1', 'lib name');
  ok(!$lims1->sample_consent_withdrawn(), 'sample consent not withdrawn');

  my $insert_size;
  lives_ok {$insert_size = $lims1->required_insert_size_range} 'insert size for the first lane';
  is ($insert_size->{'from'}, 300, 'required FROM insert size');
  is ($insert_size->{'to'}, 400, 'required TO insert size');
}

{
  my $lims4 = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => '4775',
                                 position         => 4);
  is ($lims4->is_control, 1, 'is control');
  is ($lims4->is_pool, 0, 'not pool');
  ok (!$lims4->children, 'children list is empty');
  is ($lims4->library_id, 79577, 'control id from fourth lane');
  is ($lims4->library_name, 79577, 'control name from fourth lane');
  is ($lims4->sample_id, 9836, 'sample id from fourth lane');
  ok (!$lims4->study_id, 'study id from fourth lane undef');
  ok (!$lims4->required_insert_size_range, 'no insert size for control lane');

  my $lims6 = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => '4775',
                                 position         => 6);
  is ($lims6->study_id, 333, 'study id');
  cmp_ok ($lims6->study_name, q(eq), q(CLL whole genome), 'study name');

  cmp_bag ($lims6->email_addresses,['clowdy@sanger.ac.uk', 'rainy@sanger.ac.uk', 'stormy@sanger.ac.uk', 'sunny@sanger.ac.uk'],'All email addresses');
  cmp_bag ($lims6->email_addresses_of_managers,[qw(sunny@sanger.ac.uk)],'Managers email addresses');
  is_deeply ($lims6->email_addresses_of_followers,[qw(clowdy@sanger.ac.uk rainy@sanger.ac.uk stormy@sanger.ac.uk)],'Followers email addresses');
  is_deeply ($lims6->email_addresses_of_owners,[qw(sunny@sanger.ac.uk)],'Owners email addresses');

  is ($lims6->study_alignments_in_bam, 1,'do bam alignments');
}

{
  my $lims7 = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 16249,
                                 position         => 1);
  ok (!$lims7->bait_name, 'bait name undefined');
  ok ($lims7->is_pool, 'lane is a pool');
  ok (!$lims7->is_control, 'lane is not control');
  is (scalar $lims7->children, 9, 'nine-long children list');
  is ($lims7->spiked_phix_tag_index, 168, 'spike index');

  $lims7 = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 16249,
                                 position         => 1,
                                 tag_index        => 0,);
  ok (!$lims7->bait_name, 'bait name undefined');
  ok ($lims7->is_pool, 'tag zero is a pool');
  ok (!$lims7->is_control, 'tag zero is not control');
  is (scalar $lims7->children, 9, 'tag zero - nine-long children list');
  is ($lims7->spiked_phix_tag_index, 168, 'spike index');

  $lims7 = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 16249,
                                 position         => 1,
                                 tag_index        => 2,);
  is($lims7->bait_name, 'Human all exon 50MB', 'bait name for a plex');
  is ($lims7->spiked_phix_tag_index, 168, 'spike index');
  ok (!$lims7->children, 'children list is empty');
  ok (!$lims7->is_control, 'tag 2 is not control');

  $lims7 = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 16249,
                                 position         => 1,
                                 tag_index        => 168,);
  is ($lims7->bait_name, undef, 'bait name undefined for spiked phix plex');
  ok (!$lims7->is_pool, 'is not a pool');
  ok ($lims7->is_control, 'tag 168 is control');
  is ($lims7->spiked_phix_tag_index, 168, 'spike index');
}

{
  my $lims = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 15728);
  is (scalar $lims->children, 8, '8 child lanes');

  $lims = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 15728,
                                 position         => 1);
  is (scalar $lims->children, 9, 'nine child plexes');

  $lims = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 15728,
                                 position         => 1,
                                 tag_index        => 3,);
  is( $lims->sample_id, 1299694, 'sample id');
  is( $lims->default_tag_sequence, 'TTAGGC', 'tag sequence');
  is( $lims->default_library_type, 'Agilent Pulldown', 'library type');
  is( $lims->bait_name, 'DDD custom library', 'bait name');
  is( $lims->project_cost_code, 'S0802', 'project code code');
  is( $lims->sample_reference_genome, 'Not suitable for alignment', 'sample ref genome');
  ok( $lims->sample_consent_withdrawn(), 'sample consent withdrawn' );
}

{
  my $lims = st::api::lims::ml_warehouse->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043);

  my @lanes = $lims->children;
  is (scalar @lanes, 1, 'one lane returned');
  my $lane = $lanes[0];
  is ($lane->position, 1, 'position is 1');
  is ($lane->is_pool, 1, 'is_pool true on lane level');
  ok (!$lane->is_control, 'not a control lane');
  is ($lane->library_id, undef, 'library_id indefined for a pool');
  is ($lane->spiked_phix_tag_index, undef, 'spike index undefined');
  my @plexes;
  lives_ok {@plexes = $lane->children}  'can get plex-level objects';
  is (scalar @plexes, 96, '96 plexes returned');
  is ($plexes[0]->position, 1, 'position of the first plex is 1');
  is ($plexes[0]->tag_index, 1, 'tag_index of the first plex is 1');
  is ($plexes[0]->library_id, 7583507, 'library_id of the first plex');
  is ($plexes[0]->sample_name, 'first', 'sample_name of the first plex');
  is ($plexes[0]->sample_id, 1650304, 'sample_id of the first plex');
  is ($plexes[0]->sample_reference_genome, 'Anopheles_gambiae (PEST)', 'sample ref genome');
  is ($plexes[0]->study_reference_genome, ' ', 'study ref genome undefined');
  is ($plexes[0]->is_pool, 0, 'is_pool false on plex level');
  is ($plexes[0]->is_control, 0, 'is_control false on for a plex');
  is ($plexes[0]->default_tag_sequence, 'ATCACGTT', 'default tag sequence of the first plex');
  is ($plexes[0]->spiked_phix_tag_index, undef, 'spike index undefined');
  is ($plexes[1]->study_id, 2077, 'plex study_id');
  is ($plexes[1]->sample_reference_genome, 'Anopheles_gambiae (PEST)', 'sample ref genome undefined');
  is ($plexes[1]->study_reference_genome, ' ', 'study ref genome');
  is ($plexes[95]->position, 1, 'position of the last plex is 1');
  is ($plexes[95]->tag_index, 96, 'tag_index of the last plex is 96');
  is ($plexes[95]->default_tag_sequence, 'GTCTTGGC', 'tag sequence of the last plex');
  is ($plexes[95]->library_id, 7583507, 'library_id of the last plex');
  is ($plexes[95]->sample_name, 'second', 'sample_name of the last plex');
}

1;