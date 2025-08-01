(function($) {
"use strict";

/*------------------------------------------------------------------
[Table of contents]

1. Auto Height Function
2. Validateemail Function
3. Animate Init
4. Preloader
5. Parallax Init
6. Apps Craft Top Menu Offset
7. Apps Craft Footer Menu Offset
8. Apps Craft Sync Slider
9. Apps Craft Video pop UP
10. Apps Craft Video Background
11. Apps Craft Welcome Slider
12. Apps Craft Accordion
13. Contact Form
14. Newsletter Subscription
15. Skrollr Init
16. sidebar menu
17. particle active
18. Sticky Menu
18. 3D Slider
19.  Apps Craft - MENU TOGGLE INIT
20. Apps Craft - Parallax on mouseover
21. Apps Craft - V9 Screenshot


-------------------------------------------------------------------*/

  /*=============================================== 
      1. Auto Height Function
  ================================================*/
  function autoHeight() {
    var why_choose_img = $('.apps-craft-why-chose-img'),
      why_choose_txt = $('.apps-craft-why-choose-us-container');

      why_choose_txt.css('height', why_choose_img.outerHeight());
  }

  /*=============================================== 
      2. Validateemail Function
  ================================================*/
  function validateEmail(email) {
      var re = /^[a-z][a-zA-Z0-9_.]*(\.[a-zA-Z][a-zA-Z0-9_.]*)?@[a-z][a-zA-Z-0-9]*\.[a-z]+(\.[a-z]+)?$/;
      return re.test(email);
  }

  autoHeight();

  /*=============================================== 
      3. Animate Init
  ================================================*/
  new WOW().init();

$(window).on('load', function() {
  autoHeight();

  /*=============================================== 
      4. Preloader
  ================================================*/
  $('#preloader').fadeOut(450);


  $('body').addClass('apps-craft--loaded');


}); // end on.load event



$(document).ready(function(){
  autoHeight();

	/*=============================================== 
	      5. Parallax Init
	  ================================================*/
	if ($('#apps_craft_animation').length > 0 ) {
	  $('#apps_craft_animation').parallax();
	}

	// #apps_craft_animation-2 For Index Version 5
	if ($('#apps_craft_animation-2').length > 0) {
	  $('#apps_craft_animation-2').parallax();
	}

  /*=============================================== 
      6. Apps Craft Top Menu Offset
  ================================================*/
  if($('.apps-craft-menu ul li a, .apps-craft-menu-item ul li a, .apps-craft-logo a').length >0 ) {
 	$('.apps-craft-menu ul li a, .apps-craft-menu-item ul li a, .apps-craft-logo a').on('click', function(event) {
 		event.preventDefault();

 		var target = $(this.getAttribute('href'));

 		$('html, body').animate({
 			scrollTop: target.offset().top
 		}, 500);
 	});
  } // End is_exists 

  /*=============================================== 
      7. Apps Craft Footer Menu Offset
  ================================================*/
 if($('.apps-craft-footer-menu').length >0 ) {
  $( '.apps-craft-footer-menu' ).on('click', 'a', function(e){
    var href = $(this).attr("href"),
        offsetTop = href === "#" ? 0 : $(href).offset().top - 0;
    $('html, body').stop().animate({ 
        scrollTop: offsetTop,
    }, 500, "easeInOutCirc");
    e.preventDefault();
  });
  } // End is_exists

  /*=============================================== 
      8. Apps Craft Sync Slider
  ================================================*/

  if ($('#apps-craft-commentor-slider').length >0) {

    var sync1 = $("#apps-craft-commentor-slider");
    var sync2 = $("#apps-craft-testimonial-thumb");

    sync1.owlCarousel({
      singleItem : true,
      // slideSpeed : 1000,
      pagination:false,
      navigation: false,
      addClassActive : true,
      afterAction : syncPosition,
      responsiveRefreshRate : 200,
      transitionStyle : "fade",
    });

    $(".next").on('click', function(){
      sync1.trigger('owl.next');
    });
    $(".prev").on('click', function(){
      sync1.trigger('owl.prev');
    });

    sync2.owlCarousel({
      items : 3,
      itemsDesktop      : [1199,3],
      itemsDesktopSmall     : [979,3],
      itemsTablet       : [768,3],
      itemsMobile       : [479,1],
      pagination:false,
      navigation: false,
      responsiveRefreshRate : 100,
      afterInit : function(el){
        el.find(".owl-item").eq(0).addClass("synced");
      }
    });

    function syncPosition(el){
      var current = this.currentItem;
      $("#apps-craft-testimonial-thumb")
        .find(".owl-item")
        .removeClass("synced")
        .eq(current)
        .addClass("synced")
      if($("#apps-craft-testimonial-thumb").data("owlCarousel") !== undefined){
        center(current)
      }
    }

    $("#apps-craft-testimonial-thumb").on("click", ".owl-item", function(e){
      e.preventDefault();
      var number = $(this).data("owlItem");
      sync1.trigger("owl.goTo",number);
    });

    function center(number){
      var sync2visible = sync2.data("owlCarousel").owl.visibleItems;
      var num = number;
      var found = false;
      for(var i in sync2visible){
        if(num === sync2visible[i]){
          var found = true;
        }
      }

      if(found===false){
        if(num>sync2visible[sync2visible.length-1]){
          sync2.trigger("owl.goTo", num - sync2visible.length+2)
        }else{
          if(num - 1 === -1){
            num = 0;
          }
          sync2.trigger("owl.goTo", num);
        }
      } else if(num === sync2visible[sync2visible.length-1]){
        sync2.trigger("owl.goTo", sync2visible[1])
      } else if(num === sync2visible[0]){
        sync2.trigger("owl.goTo", num-1)
      }
      
    }
} // Apps Craft Sync Slider

/*=============================================== 
      9. Apps Craft Video pop UP
  ================================================*/
if ($('.apps-craft-popup-video').length > 0) {
  $('.apps-craft-popup-video').magnificPopup({
    disableOn: 700,
    type: 'iframe',
    mainClass: 'mfp-fade',
    removalDelay: 160,
    preloader: true,

    fixedContentPos: false
  });
} // Apps Craft Video Pop UP

/*=============================================== 
     10. Apps Craft Video Background
  ================================================*/
if ($('.apps-craft-video-bg-section').length > 0) {
  var options = { 
    videoId: 'waTteMeg4Ag', 
    start: 3 ,
    width: $(window).width(),
    wrapperZIndex: 99,
    repeat: true,
  };
  $('.apps-craft-video-bg-section').tubular(options);
}

/*=============================================== 
     11. Apps Craft Welcome Slider
  ================================================*/
if ($('#apps-craft-welcome-slider').length > 0) {
  var owl1 = $("#apps-craft-welcome-slider");
  owl1.owlCarousel({
      slideSpeed : 300,
      paginationSpeed : 400,
      items : 1,
      itemsDesktop      : [1199,1],
      itemsDesktopSmall     : [979,1],
      itemsTablet       : [768,1],
      itemsMobile       : [479,1],
      touchDrag: true,
      mouseDrag: true,
      pagination: true,
      navigation: false,
      addClassActive: true,
  });
}


$("#showcaseSlider").owlCarousel({

    pagination: true,
    navigation : false, // Show next and prev buttons
    slideSpeed : 300,
    paginationSpeed : 400,
    singleItem:true

});

$("#apps-craft-appscreen-slide").owlCarousel({
    pagination: true,
    navigation : false, // Show next and prev buttons
    slideSpeed : 300,
    paginationSpeed : 400,
    transitionStyle : "fade",
    singleItem:true
});


/*=============================================== 
     12. Apps Craft Accordion
  ================================================*/
if ($('.apps-craft-accordion .panel-title').length > 0) {
  $('.apps-craft-accordion .panel-title').click(function(){
    $('.apps-craft-accordion .panel-title').removeClass('click');
    $(this).addClass('click');
  });
}

/*=============================================== 
			13. Contact Form
		================================================*/

		if ($('#apps-craft-form').length > 0) {

	  var apps_craft_contact_btn = $('#apps-craft-input-send'),
	      apps_craft_form = $('#apps-craft-form');

	  apps_craft_form.on('submit', function(e){
	    e.preventDefault();

	    $('.apps_craft_error, .apps-craft-success-message, .apps-craft-loader').remove();
	    $('.form-group input').removeClass('apps_craft_input_error');

	    var apps_craft_input_name     = $('#apps-craft-input-name'),
	        apps_craft_input_email    = $('#apps-craft-input-email'),
	        apps_craft_input_message  = $('#apps-craft-input-message'),
	        apps_craft_error          = false,
	        self                  = $(this);

	    if(apps_craft_input_email.val() === ''){
	      apps_craft_input_email.before('<div class="apps_craft_error">Email Address Should not be emtpy.</div>').hide().fadeIn();
	      apps_craft_input_email.addClass('apps_craft_input_error');
	      apps_craft_error = true;
	    } else if(!validateEmail(apps_craft_input_email.val().toLowerCase())){
	      apps_craft_input_email.before('<div class="apps_craft_error">Email Address Should be valid.</div>').hide().fadeIn();
	      apps_craft_input_email.addClass('apps_craft_input_error');
	      apps_craft_error = true;
	    }else if(apps_craft_input_message.val() === ''){
	      apps_craft_input_message.before('<div class="apps_craft_error">Message Should not be emtpy.</div>').hide().fadeIn();
	      apps_craft_input_message.addClass('apps_craft_input_error');
	      apps_craft_error = true;
	    }

	    if(apps_craft_error === false){
	      apps_craft_contact_btn.before('<span class="apps-craft-loader apps-craft-loader1"></span>').hide().fadeIn();
	      $.ajax({
	        type: "POST",
	        url: "php/contact-form.php",
	        data: {
	          'apps_craft_input_name' : apps_craft_input_name.val(),
	          'apps_craft_input_email' : apps_craft_input_email.val(),
	          'apps_craft_input_message' : apps_craft_input_message.val()
	        },
	        success: function(result){
	           apps_craft_contact_btn.after('<div class="apps-craft-success-message">' + result + '</div>').hide().fadeIn();

	           $(".apps-craft-loader").fadeOut("normal", function() {
	              $(this).remove();
	          });
	        }
	      });
	    }
	  });
  }

  /*=============================================== 
       14. Newsletter Subscription
  ================================================*/
  if ($('.mc-form').length > 0) {
  $('.mc-form').each(function(index){
    var formthis = $(this).ajaxChimp({
        url: '//pixiefy.us13.list-manage.com/subscribe/post?u=1c19cb3fd3c3c6c56177c50ea&amp;id=967a07b6cc',
        callback: callbackFunction
    });
     function callbackFunction(resp){
      formthis.find('label').addClass('apps-craft-subscribed-label');
    }
  });
 }


/*=============================================== 
      15. Skrollr Init
  ================================================*/
var mySkrollr = skrollr.init({
    forceHeight: false,
    easings: {
        easeOutBack: function (p, s) {
            s = 1.70158;
            p = p - 1;
            return (p * p * ((s + 1) * p + s) + 1);
        }
    },
    mobileCheck: function() {
        //hack - forces mobile version to be off
        return false;
    }
});


/*--------------------------------------------------------------
  20. RIPPLES CANVAS
--------------------------------------------------------------*/
var ripple = $('body.apps-craft-v8 #apps-craft-home');
if ($('body.apps-craft-v8 #apps-craft-home').length > 0 ) {
  ripple.ripples({
    resolution: 512,
    dropRadius: 10, //px
    perturbance: 0.04,
    interactive: true
  });
  setInterval(function () {
    var $el = ripple;
    var x = Math.random() * $el.outerWidth();
    var y = Math.random() * $el.outerHeight();
    var dropRadius = 20;
    var strength = 0.04 + Math.random() * 0.04;

    $el.ripples('drop', x, y, dropRadius, strength);
  }, 3000);
}

/*=============================================== 
      16. sidebar menu
  ================================================*/

// Apps Craft Side bar Menu
$('.apps-craft-humberger-menu').on('click', function() {
	if ($('.apps-craft-side-bar-menu').hasClass('active')) {
		$('.apps-craft-side-bar-menu').removeClass('active');
	} else {
		$('.apps-craft-side-bar-menu').addClass('active');
	}
});

$('.apps-craft-menu-item ul li a, .apps-craft-logo a').on('click', function(event) {
	if ($('.apps-craft-side-bar-menu').hasClass('active')) {
		$('.apps-craft-side-bar-menu').removeClass('active');
	}
});

/*=============================================== 
      17. particle active
  ================================================*/

if ($('body').hasClass('apps-craft-particle')) {

  particlesJS("apps-craft-home", {
    "particles": {
      "number": {
        "value": 500,
        "density": {
        "enable": true,
        "value_area": 500
      }
    },
    "color": {
      "value": "#ffffff"
    },
    "shape": {
      "type": "circle",
      "stroke": {
      "width": 0,
      "color": "#fff"
    },
    "polygon": {
      "nb_sides": 5
    },
    "image": {
      "width": 100,
      "height": 100
      }
    },
      "opacity": {
        "value": 0.5,
        "random": false,
        "anim": {
        "enable": true,
        "speed": 1,
        "opacity_min": 0.1,
        "sync": false
      }
    },
      "size": {
        "value": 2,
        "random": true,
        "anim": {
        "enable": false,
        "speed": 20,
        "size_min": 2,
        "sync": false
      }
    },
      "line_linked": {
      "enable": false,
      "distance": 1000,
      "color": "#ffffff",
      "opacity": 0.4,
      "width": 1
    },
      "move": {
        "enable": true,
        "speed": 1.603412060865523,
        "direction": "top",
        "random": false,
        "straight": false,
        "out_mode": "out",
        "bounce": false,
        "attract": {
          "enable": false,
          "rotateX": 600,
          "rotateY": 1200
      }
    }
    },
    "interactivity": {
      "detect_on": "canvas",
    "events": {
    "onhover": {
      "enable": true,
      "mode": "repulse"
    },
    "onclick": {
      "enable": true,
      "mode": "push"
    },
      "resize": true
    },
    "modes": {
    "grab": {
      "distance": 100,
    "line_linked": {
      "opacity": 1
    }
    },
    "bubble": {
      "distance": 400,
      "size": 40,
      "duration": 2,
      "opacity": 8,
      "speed": 3
    },
    "repulse": {
      "distance": 50,
      "duration": 0.4
    },
    "push": {
      "particles_nb": 50
    },
    "remove": {
      "particles_nb": 2
    }
    }
    },
    "retina_detect": true
  });
  

}



// Version 18 Apps Screen
  function showpanel() {
    $('.appscraft-screen-container').removeClass('startup');
    $('.ball').addClass('active').delay(2000).queue(function(next) {
      $(this).removeClass('active');
      next();
    });
  }
  
  $('.ball').click(function() {
    $(this).toggleClass('active');
  });


  $('i').click(function() {
    $('.ball').addClass('expand');
    $('.back').addClass('show');
  });

  $('.back').click(function() {
    $(this).removeClass('show');
    $('.ball').removeClass('expand');
    $('.appscraft-screen-container').addClass('shake').delay(500).queue(function(next) {
      $(this).removeClass('shake');
      next();
    });
  });
  
 setTimeout(showpanel, 1800);




}); // End Document Ready


/*=============================================== 
      18. Sticky Menu
  ================================================*/

$(window).scroll(function(){
  if ($(window).scrollTop() > 50) {
     $('.apps-craft-main-menu-area').addClass('sticky-menu'); 
  } else {
      $('.apps-craft-main-menu-area').removeClass('sticky-menu');
  }
}); // End Scroll Function


$(window).on('resize', function(){
  autoHeight();
}); // End Resize


/*=============================================== 
      18. 3D Slider
  ================================================*/

if ($('#carousel').length > 0 ) {
var transformProp = Modernizr.prefixed('transform');

    function Carousel3D ( el ) {
      this.element = el;

      this.rotation = 0;
      this.panelCount = 0;
      this.totalPanelCount = this.element.children.length;
      this.theta = 0;

      this.isHorizontal = true;

    }

    Carousel3D.prototype.modify = function() {

      var panel, angle, i;

      this.panelSize = this.element[ this.isHorizontal ? 'offsetWidth' : 'offsetHeight' ];
      this.rotateFn = this.isHorizontal ? 'rotateY' : 'rotateX';
      this.theta = 360 / this.panelCount;

      // do some trig to figure out how big the carousel
      // is in 3D space
      this.radius = Math.round( ( this.panelSize / 2) / Math.tan( Math.PI / this.panelCount ) );

      for ( i = 0; i < this.panelCount; i++ ) {
        panel = this.element.children[i];
        angle = this.theta * i;
        panel.style.opacity = 1;
        //panel.style.backgroundColor = 'hsla(' + angle + ', 100%, 50%, 0.8)';
        // rotate panel, then push it out in 3D space
        panel.style[ transformProp ] = this.rotateFn + '(' + angle + 'deg) translateZ(' + this.radius + 'px)';
      }

      // hide other panels
      for (  ; i < this.totalPanelCount; i++ ) {
        panel = this.element.children[i];
        panel.style.opacity = 0;
        panel.style[ transformProp ] = 'none';
      }

      // adjust rotation so panels are always flat
      this.rotation = Math.round( this.rotation / this.theta ) * this.theta;

      this.transform();

    };

    Carousel3D.prototype.transform = function() {
      // push the carousel back in 3D space,
      // and rotate it
      this.element.style[ transformProp ] = 'translateZ(-' + this.radius + 'px) ' + this.rotateFn + '(' + this.rotation + 'deg)';
    };



    var init = function() {


      var carousel = new Carousel3D( document.getElementById('carousel') ),
          navButtons = document.querySelectorAll('#navigation button'),

          onNavButtonClick = function( event ){
            var increment = parseInt( event.target.getAttribute('data-increment') );
            carousel.rotation += carousel.theta * increment * -1;
            carousel.transform();
          };

      // populate on startup
      carousel.panelCount = 12;
      carousel.modify();
    
      for (var i=0; i < 2; i++) {
        navButtons[i].addEventListener( 'click', onNavButtonClick, false);
      }

      setTimeout( function(){
        document.body.addClassName('ready');
      }, 0);

    };

    window.addEventListener( 'DOMContentLoaded', init, false);
}

  /*--------------------------------------------------------------
    19.  Apps Craft - MENU TOGGLE INIT
  --------------------------------------------------------------*/
  var apps_main_menu_icon = $("#apps-craft-main-menu-icon"),
      apps_main_menu_nave = $('#apps-craft-menu'),
      apps_main_menu_link = $("#apps-craft-menu ul li a");


  if(apps_main_menu_icon.length >0 ){
    apps_main_menu_icon.on('click', function(){
      apps_main_menu_nave.slideToggle(500);
    });
  }


  function appscraft_menu_toggle(){
    if($(window).width() <=767){
        apps_main_menu_link.on('click', function(){
        apps_main_menu_nave.slideToggle('fast');
      });
    }
  }


  if(apps_main_menu_link.length >0 ){
    appscraft_menu_toggle();
  }

  $(window).on('resize', appscraft_menu_toggle);


  /*--------------------------------------------------------------
    20. Apps Craft - Parallax on mouseover
  --------------------------------------------------------------*/
  $(document).on("mousemove", function( e ) {
if ($('.parallax').length > 0 ) {
      $( '.apps-craft-welcome-content.parallax' ).parallax( -40, e );
      $( '.apps-craft-welcome-screenshort.parallax' ).parallax( 40 , e );
}
  }); // end document mouvemove



  /*--------------------------------------------------------------
    21. Apps Craft - V9 Screenshot
  --------------------------------------------------------------*/

// Home 9 promo header carousel
if ($('.swiper-container.one').length > 0 ) {
var swiper = new Swiper('.swiper-container.one', {
    autoplay: 3000,
    speed: 3000,
    effect: 'coverflow',
    loop: true,
    centeredSlides: true,
    slidesPerView: 'auto',
    coverflow: {
        rotate: 0,
        stretch: 100,
        depth: 300,
        modifier: 1.5,
        slideShadows : false,
    }
});
}

// App screenshot carousel Home 9
if ($('.swiper-container.two').length > 0 ) {
var swiper = new Swiper('.swiper-container.two', {
    pagination: '.swiper-pagination',
    paginationClickable: true,
    effect: 'coverflow',
    loop: true,
    centeredSlides: true,
    slidesPerView: 'auto',
    coverflow: {
        rotate: 0,
        stretch: 100,
        depth: 150,
        modifier: 1.5,
        slideShadows : false,
    }
});
}


})(jQuery);
