use strict;
use warnings;
use WWW::Mechanize;
#use HTTP::Tiny;
use HTML::TreeBuilder;
use List::MoreUtils qw(uniq);

my $username = '';
my $password = '';

my $mech = WWW::Mechanize->new();

my $path = "";
system "mkdir -p $path; echo \"Created Folder (Did you want this?)\"" unless(-d $path);

#('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36');
$mech->agent( 'Windows IE 6');

my $login_url = 'https://www.deviantart.com/users/login';
$mech->get($login_url);

#Inital loading site
if ($mech->success) {
	print "success login\n";

	#DA uses two part login
	$mech->form_number(1);
	$mech->field('username', $username);


	$mech->click_button(id => 'loginbutton');
	print"GOT thru first\n";
	sleep(0.5);
	my $csrf;
	my $form = $mech->form_number(1);
	
	my @hidden_inputs = $mech->find_all_inputs;
	foreach my $input (@hidden_inputs) {
		if($input->name eq 'csrf_token') {
			$csrf = $input->value;
			print "on user page\n";
			last;
		}
	}

	print "Form action past user, into get(): " . $form->action() . "\n";

	$mech->get($form->action());
	$mech->form_number(1); 
		
	@hidden_inputs = $mech->find_all_inputs;
	foreach my $input (@hidden_inputs) {
		if($input->name eq 'csrf_token') {
			$csrf = $input->value;
			print "on pass page\n";
			last;
		}
	}


	$mech->field('password', $password);
	$mech->click_button(id => 'loginbutton');  
	if ($mech->content =~ /[Ww]atch/) { 
	print "Login successful!\n";

	#go to favorites
	my $url = "http://www.deviantart.com/$username/favourites/all?page=";
	my $urlPageless = substr $url, 0, -6;
	print "$urlPageless\n";
	my $sec = "1";
	$mech->get($url.$sec);
	die "mech failed to load Favourites\n" unless $mech->success();
	my $content = $mech->content();

	my $tree = HTML::TreeBuilder->new();
	$tree->parse($content);

	my @links = $tree->find("a");
	my $max = 1;
	foreach my $link (@links) {
		$link = $link->attr('href');
		if (index($link, $urlPageless) != -1)  {
			$link =~ /page=(\d+)/; 
			$max = ($max > $1) ? $max : $1;
		}#get max pages
	}
	print "max is $max\n";

	my $url2;
	my $scalar = 1;
	my $image_url;
	my @allLinks;
	print "$max\n";
	do {
		$mech->get($url.$sec);
		#print $mech->uri();
		die "mech didn't get new\n" unless $mech->success();
		$content = $mech->content();
		$tree->parse($content);
		my @links = $tree->find('a'); #anchor tags
		print "\nNEW URL ||| $url$sec\n";
		my $file;
		foreach my $link (@links) {
			$url2 = $link->attr("href");	
			if((index($url2, "/art/") != -1) && (!($url2 =~ /\#comments/))  ) {
				if($scalar == 1) { #double links
					push @allLinks, $url2;
				}		
				$scalar *= -1;
			} 
		}#got all of em
		print "GOT ALL OF THEM ON PAGE $sec\n";
		$sec++;
		print"MAX still is $max\n";
	} while($sec <= $max); #exists another page
	$tree->delete;
	my @unique = uniq @allLinks;
	undef @allLinks;

	my $extension;
	my $handler;
	my $file;
	open my $errorHandle, '>', "$path/FileErrors.txt";
	open my $namesHandle, '>', "$path/sources.txt";
	unshift @unique, "lal";
	while (my $things = shift @unique) { 
		print "$things\n"; 
		print "Found link: $things\n"; #download
		eval {
			$mech->get($things);
			die "error with link (page $sec)\n" unless $mech->success();
			$image_url = $mech->find_image( url_regex => qr/images-wixmp/, ); die "image not found\n" unless $image_url;
			
			#$mech->get($image_url->url(), ':content_file' => "$path/$file"); die "failed to download\n" . $mech->status() unless $mech->success();
			$image_url = $mech->get($image_url->url()); die "failed to download\n" . $mech->status() unless $mech->success();
			$extension = $image_url->header('Content-Type');
			$extension = "$extension" =~ /([^\/]+)$/ ? $1 : die "File extension wasn't read\n";
			$file = "$things" =~ /\/art\/([^\/]+)/ ? $1 : die "Title wasn't read\n";
			#file = "$things";     
			#$file =~ s/^.*?\Q\/art\/\E//;

			print ref $file;
			print "$file\n";

			print "$path/$file.$extension\n";
			open $handler, '>', "$path/$file.$extension";
			binmode $handler;
			print $handler $image_url->decoded_content(); 
			$handler->flush();
			print $namesHandle "$things\n";
			$errorHandle->flush();
		};
		if($@) {
			print "ERROR DOWNLOADING: $things\n";		
			push @unique, $things;	
			print $errorHandle ("$things | ". localtime() . "\n");
			$errorHandle->flush();
			print "|||Logged to 'FileErrors.txt': Download will be retried later.|||\n";
			print "|||If persists, use the FileDownloader or manually download.|||\n";
			sleep(2);
		}

	}
	close $errorHandle;
	close $namesHandle;
	close $handler;
	print scalar @unique, "\n";

}	else {
		print "Login failed: " . $mech->content . "\n";
	}
}	else {
	print "earliest fail.\n";
}



